from asyncio import run, sleep
from zipfile import ZipFile

from pybricksdev.connections import CharacterGlue, USBConnection
from pybricksdev.flash import crc32_checksum

class USBREPLConnection(CharacterGlue, USBConnection):
    """Run commands in a MicroPython repl and print or eval the output."""

    def __init__(self, **kwargs):
        """Initialize base class with appropriate EOL for this connection."""
        self.stdout = []
        super().__init__(EOL=b'\r\n', **kwargs)

    def line_handler(self, line):
        """Override base class to just store all incoming lines."""
        self.stdout.append(bytes(line))

    def is_ready(self):
        """Checks if REPL is ready for next command."""
        return self.char_buf[-4:] == b'>>> '

    async def reset(self):
        """Resets into REPL mode even if something is running."""
        self.stdout = []
        while not self.is_ready():
            await self.write(b'\x03')
            await sleep(0.1)

    async def reboot(self):
        """Soft reboots the board."""
        await self.reset()
        await self.write(b'\x04')
        await sleep(3)

    async def exec_line(self, line, wait=True):
        """Executes one line of code and returns the standard output result."""
        encoded = line.encode()
        start_index = len(self.stdout)
        await self.write(encoded + b'\r\n')

        if not wait:
            return

        while len(self.stdout) == start_index:
            await sleep(0.01)
        if self.stdout[start_index] != b'>>> ' + encoded:
            raise ValueError(b"Failed to execute line: {0}.".format(line))
        while not self.is_ready():
            await sleep(0.01)
        if len(self.stdout) > start_index + 1:
            return b"".join(self.stdout[start_index + 1:])

    async def exec_and_eval(self, line):
        """Executes one line of code and evaluates the output."""
        return eval(await self.exec_line(line))


def get_combined_firmware(bin1, bin2):
    """Combines two firmware binary blobs and swaps their boot vectors."""

    # These values are for SPIKE Prime. Also see prime_hub.ld.
    FLASH_SIZE = 1024 * 1024
    BIN1_BASE_OFFSET = 0x8000
    BIN2_BASE_OFFSET = 0xC0000

    bin1_size = len(bin1)
    bin2_size = len(bin2)
    bin2_offset = BIN2_BASE_OFFSET - BIN1_BASE_OFFSET
    size = bin2_offset + bin2_size
    max_size = FLASH_SIZE - BIN1_BASE_OFFSET

    if bin1_size >= bin2_offset:
        raise ValueError("base firmware is too big!")
    if size >= max_size:
        raise ValueError("extra firmware is too big!")

    # Create a new combined firmware blob
    blob = bytearray(bin1 + b'\xff' * (bin2_offset - bin1_size) + bin2)

    # Read reset handler pointers in vector tables.
    bin1_reset_handler = bin1[4:8]
    bin2_reset_handler = bin2[4:8]

    # Swap reset handler pointers.
    blob[4:8] = bin2_reset_handler
    blob[bin2_offset + 4: bin2_offset + 8] = bin1_reset_handler

    # The final checksum is for the entire new blob
    # This overrides the checksum of the second firmware.
    blob[-4:] = crc32_checksum(blob, max_size).to_bytes(4, "little")

    # Return result
    return bytes(blob)


class REPLDualBootInstaller(USBREPLConnection):

    PYBRICKS_BASE = 0x80C0000
    FLASH_OFFSET = 0x8008000
    READ_BLOCKS = 8

    def __init__(self):
        self.current_progress = 0
        super().__init__()

    async def get_base_firmware_info(self):
        """Gets firmware version without reboot"""

        # Read boot sector
        boot_data = await self.exec_and_eval(
            "import firmware; firmware.flash_read(0x200)"
        )

        # Read firmware version data
        version_position = int.from_bytes(boot_data[0:4], 'little') - self.FLASH_OFFSET
        base_firmware_version = (await self.exec_and_eval(
            "firmware.flash_read({0})".format(version_position)
        ))[0:20].decode()

        # Read firmware size data
        checksum_position = int.from_bytes(boot_data[4:8], 'little') - self.FLASH_OFFSET
        base_firmware_checksum = int.from_bytes((await self.exec_and_eval(
            "firmware.flash_read({0})".format(checksum_position)))[0:4], 'little')
        base_firmware_size = checksum_position + 4

        # Read the boot vector
        base_firmware_vector = await self.get_base_firmware_vector()

        # Return firmware info
        return {
            "size": base_firmware_size,
            "version": base_firmware_version,
            "checksum": base_firmware_checksum,
            "boot_vector": base_firmware_vector
        }

    async def get_base_firmware_vector(self):
        """Gets base firmware boot vector, already accounting for dual boot."""

        # Import firmware module
        await self.exec_line("import firmware")

        # Read base vector sector
        base_vector_data = (await self.exec_and_eval(
            "import firmware; firmware.flash_read(0x000)"
        ))[4:8]

        # If it's running pure stock firmware, return as is.
        if int.from_bytes(base_vector_data, 'little') < self.PYBRICKS_BASE:
            print("Currently running single-boot firmware.")
            return base_vector_data

        # Otherwise read the boot vector in Pybricks, which points at base.
        print("Currently running dual-boot firmware.")
        return (await self.exec_and_eval(
            "import firmware; firmware.flash_read({0})".format(
                self.PYBRICKS_BASE - self.FLASH_OFFSET)))[4:8]

    async def get_flash_block(self, address):
        return await self.exec_and_eval(
                "+".join(["flr({0})".format(address + i * 32) for i in range(self.READ_BLOCKS)])
        )

    async def get_base_firmware_blob(self, base_firmware_info):
        """Backs up original firmware with original boot vector."""

        size = base_firmware_info["size"]
        print("Backing up {0} bytes of original firmware. Progress:".format(size))

        # Import abbreviated function to reduce data transfer
        await self.exec_line("from firmware import flash_read as flr")

        # Read the first chunk and reinstate the original boot vector
        blob = await self.get_flash_block(0)
        blob = blob[0:4] + base_firmware_info["boot_vector"] + blob[8:]

        # Read the remainder up to the requested size
        bytes_read = len(blob)

        # Yield new blocks until done.
        while bytes_read < size:

            # Read several chunks of 32 bytes into one block.
            block = await self.get_flash_block(bytes_read)
            bytes_read += len(block)

            # If we read past the end, cut off the extraneous bytes.
            if bytes_read > size:
                block = block[0: size % len(block)]

            # Add the resulting block.
            blob += block

            # Progress percentage
            progress = int(len(blob) / size * 100)
            print("{0}%".format(progress), end="\r")

            # Scale progress to fill up first two rows
            await self.show_progress(progress / 2.77 + 4)

        # Verify checksum
        read_checksum = int.from_bytes(blob[-4:], 'little')
        calculated_checksum = crc32_checksum(blob, len(blob))
        if not calculated_checksum == base_firmware_info["checksum"] == read_checksum:
            raise IOError("Backup does not have expected checksum.")

        print("Backup complete\n")
        return blob

    async def write_firmware_blob(self, firmware_blob):
        """Writes firmware to external flash to install on next boot."""
        offline_checksum = crc32_checksum(firmware_blob, len(firmware_blob))
        size = len(firmware_blob)

        print("Preparing external flash.")
        await self.exec_line("import firmware")
        await self.exec_line("from firmware import appl_image_store as flw")
        await self.exec_line("firmware.appl_image_initialise({0})".format(size))
        await self.show_progress(44)

        print("Writing firmware. Progress:")
        chunk_size = self.READ_BLOCKS * 32
        chunks = (firmware_blob[i:i + chunk_size] for i in range(0, size, chunk_size))
        for i, chunk in enumerate(chunks):
            # Write the chunk
            await self.exec_line("flw({0})".format(repr(chunk)))

            # Progress percentage
            progress = int(i * chunk_size / size * 100)
            print("{0}%".format(progress), end="\r")

            # Scale progress to fill up Last three rows
            await self.show_progress(44 + progress / 100 * 56)

        await self.show_progress(100)
        await sleep(0.2)
        print("Done! Verifying firmware.")
        read_firmware_info = await self.exec_and_eval("firmware.info()")

        if not read_firmware_info['upload_finished'] or \
                read_firmware_info['valid'] == -1 or \
                read_firmware_info['new_appl_image_calc_checksum'] != offline_checksum:
            raise IOError("Failed to download firmware.", read_firmware_info)

        # Reboot the hub
        print("Download succeeded. Rebooting now...")
        await self.exec_line("import umachine; umachine.reset()", wait=False)

    async def show_image(self, image):
        """Shows an image made as a 2D list of intensities."""

        # Convert 2D list to expected string format
        image_string = ":".join([
            "".join([str(round(min(abs(i), 100)*0.09)) for i in col]) for col in image
        ])

        # Display the image
        await self.exec_line("import hub")
        await self.exec_line("hub.display.show(hub.Image('{0}'))".format(image_string))

    async def show_progress(self, progress):
        """Create 2D grid of intensities to show 0--100% 25 pixels."""
        # Avoid updating screen if there is nothing to do
        progress = int(progress)
        if progress == self.current_progress:
            return
        await self.show_image([[
                max(0, min((progress - (i * 5 + j) * 4) * 25, 100)) for j in range(5)
            ] for i in range(5)
        ])
        self.current_progress = progress

    async def install(self, firmware_archive_path):
        """Main dual boot install script."""
        await self.connect("LEGO Technic Large Hub in FS Mode")
        await self.reset()

        # Get firmware information
        base_firmware_info = await self.get_base_firmware_info()
        print("Detected firmware:")
        print(base_firmware_info)

        # Read original firmware
        base_firmware_blob = await self.get_base_firmware_blob(base_firmware_info)

        # Back up copy to disk
        with open("firmware-" + base_firmware_info["version"] + ".bin", "wb") as bin_file:
            bin_file.write(base_firmware_blob)

        # Read Pybricks dual boot build
        archive = ZipFile(firmware_archive_path)
        pybricks_blob = archive.open('firmware-dual-boot-base.bin').read()

        # Create dual boot firmware
        combined_blob = get_combined_firmware(base_firmware_blob, pybricks_blob)

        # Write (combined) firmware to external flash and reboot to install
        await self.write_firmware_blob(combined_blob)


if __name__ == "__main__":

    async def main():
        installer = REPLDualBootInstaller()
        await installer.install('../pybricks-micropython/bricks/primehub/build/firmware.zip')

    run(main())
