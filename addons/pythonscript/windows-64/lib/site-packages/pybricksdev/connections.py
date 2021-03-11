import asyncio
import asyncssh
import os
from .ble import BLEConnection
from .usbconnection import USBConnection
from .compile import compile_file
import json
import random
import base64


class CharacterGlue():
    """Glues incoming bytes into a buffer and splits it into lines."""

    def __init__(self, EOL, **kwargs):
        """Initialize the buffer.

        Arguments:
            EOL (bytes):
                Character sequence that signifies end of line.

        """
        self.EOL = EOL

        # Create empty rx buffer
        self.char_buf = bytearray(b'')

        super().__init__(**kwargs)

    def char_handler(self, char):
        """Handles new incoming characters.

        Arguments:
            char (int):
                Character/byte to process.

        Returns:
            int or None: Processed character.

        """
        self.logger.debug("RX CHAR: {0} ({1})".format(chr(char), char))
        return char

    def line_handler(self, line):
        """Handles new incoming lines.

        The default just prints the line that comes in.

        Arguments:
            line (bytearray):
                Line to process.
        """
        print(line)

    def data_handler(self, sender, data):
        """Handles new incoming data. Calls char and line parsers when ready.

        Arguments:
            sender (str):
                Sender uuid.
            data (bytearray):
                Incoming data.
        """
        self.logger.debug("RX DATA: {0}".format(data))

        # For each new character, call its handler and add to buffer if any
        for byte in data:
            append = self.char_handler(byte)
            if append is not None:
                self.char_buf.append(append)

        # Some applications don't have any lines to process
        if self.EOL is None:
            return

        # Break up data into lines and take those out of the buffer
        lines = []
        while True:
            # Find and split at end of line
            index = self.char_buf.find(self.EOL)
            # If no more line end is found, we are done
            if index < 0:
                break
            # If we found a line, save it, and take it from the buffer
            lines.append(self.char_buf[0:index])
            del self.char_buf[0:index+len(self.EOL)]

        # Call handler for each line that we found
        for line in lines:
            self.line_handler(line)


class PybricksPUPProtocol(CharacterGlue):
    """Parse and send data to make Pybricks Hubs run MicroPython scripts."""

    UNKNOWN = 0
    IDLE = 1
    RUNNING = 2
    ERROR = 3
    AWAITING_CHECKSUM = 4

    def __init__(self, **kwargs):
        """Initialize the protocol state."""
        self.state = self.UNKNOWN
        self.checksum = None
        self.checksum_ready = asyncio.Event()
        self.log_file = None
        self.output = []
        super().__init__(EOL=b'\r\n', **kwargs)

    def char_handler(self, char):
        """Handles new incoming characters.

        This overrides the same method from CharacterGlue to change what
        we do with individual incoming characters/bytes.

        If we are awaiting the checksum, it raises the event to say the
        checksum has arrived. Otherwise, it just returns the character as-is
        so it can be added to standard output.

        Arguments:
            char (int):
                Character/byte to process

        Returns:
            int or None: The same character or None if the checksum stole it.
        """
        if self.state == self.AWAITING_CHECKSUM:
            # If we are awaiting on a checksum, this is that byte. So,
            # don't add it to the buffer but tell checksum awaiter that we
            # are ready to process it.
            self.checksum = char
            self.checksum_ready.set()
            self.logger.debug("RX CHECKSUM: {0}".format(char))
            return None
        else:
            # Otherwise, return it so it gets added to standard output buffer.
            return char

    def line_handler(self, line):
        """Handles new incoming lines. Handle special actions if needed,
        otherwise just print it as regular lines.

        Arguments:
            line (bytearray):
                Line to process.
        """

        # If the line tells us about the state, set the state and be done.
        if line == b'>>>> IDLE':
            self.set_state(self.IDLE)
            return
        if line == b'>>>> RUNNING':
            self.set_state(self.RUNNING)
            return
        if line == b'>>>> ERROR':
            self.set_state(self.ERROR)
            return
        if line == b'--------------':
            return

        # The line tells us to open a log file, so do it.
        if b'PB_OF' in line:
            if self.log_file is not None:
                raise OSError("Log file is already open!")
            name = line[6:].decode()
            self.logger.info("Saving log to {0}.".format(name))
            self.log_file = open(name, 'w')
            return

        # The line tells us to close a log file, so do it.
        if b'PB_EOF' in line:
            if self.log_file is None:
                raise OSError("No log file is currently open!")
            self.logger.info("Done saving log.")
            self.log_file.close()
            self.log_file = None
            return

        # If we are processing datalog, save current line to the open file.
        if self.log_file is not None:
            print(line.decode(), file=self.log_file)
            return

        # If there is nothing special about this line, print it if requested.
        self.output.append(line)

        if self.print_output:
            print(line.decode())

    def set_state(self, new_state):
        """Updates state if it is new.

        Arguments:
            new_state (int):
                New state
        """
        if new_state != self.state:
            self.logger.debug("New State: {0}".format(new_state))
            self.state = new_state

    def prepare_checksum(self):
        """Prepare state to start receiving checksum."""
        self.set_state(self.AWAITING_CHECKSUM)
        self.checksum = None
        self.checksum_ready.clear()

    async def wait_for_checksum(self):
        """Awaits and returns a checksum character.

        Returns:
            int: checksum character
        """
        await asyncio.wait_for(self.checksum_ready.wait(), timeout=0.5)
        result = self.checksum
        self.prepare_checksum()
        self.set_state(self.IDLE)
        return result

    async def wait_until_state(self, state):
        """Awaits until the requested state is reached."""
        # FIXME: handle using event on state change
        while True:
            await asyncio.sleep(0.1)
            if self.state == state:
                break

    async def wait_until_state_is_not(self, state):
        """Awaits until the requested state is no longer active."""
        # FIXME: handle using event on state change
        while True:
            await asyncio.sleep(0.1)
            if self.state != state:
                break

    async def send_message(self, data):
        """Send bytes to the hub, and check if reply matches checksum.

        Arguments:
            data (bytearray):
                Data to write. At most 100 bytes.

        Raises:
            ValueError:
                Did not receive expected checksum for this message.
        """

        if len(data) > 100:
            raise ValueError("Cannot send this much data at once")

        # Compute expected reply
        checksum = 0
        for b in data:
            checksum ^= b

        # Clear existing checksum
        self.prepare_checksum()

        # Send the data
        await self.write(data)

        # Await the reply
        reply = await self.wait_for_checksum()
        self.logger.debug("expected: {0}, reply: {1}".format(checksum, reply))

        # Check the response
        if checksum != reply:
            raise ValueError(
                "Expected checksum {0} but received {1}.".format(
                    checksum, reply
                )
            )

    async def run(self, py_path, wait=True, print_output=True):
        """Run a Pybricks MicroPython script on the hub and print output.

        Arguments:
            py_path (str):
                Path to MicroPython script.
            wait (bool):
                Whether to wait for any output until the program completes.
            print_output(bool):
                Whether to print the standard output.
        """

        # Reset output buffer
        self.output = []
        self.print_output = print_output

        # Compile the script to mpy format
        mpy = await compile_file(py_path)

        # Get length of file and send it as bytes to hub
        length = len(mpy).to_bytes(4, byteorder='little')
        await self.send_message(length)

        # Divide script in chunks of bytes
        n = 100
        chunks = [mpy[i: i + n] for i in range(0, len(mpy), n)]

        # Send the data chunk by chunk
        for i, chunk in enumerate(chunks):
            self.logger.info("Sending: {0}%".format(
                round((i+1)/len(chunks)*100))
            )
            await self.send_message(chunk)

        # Optionally wait for the program to finish
        if wait:
            await asyncio.sleep(0.2)
            await self.wait_until_state_is_not(self.RUNNING)


class BLEPUPConnection(PybricksPUPProtocol, BLEConnection):

    def __init__(self):
        """Initialize the BLE Connection with settings for Pybricks service."""

        super().__init__(
            char_rx_UUID='6e400002-b5a3-f393-e0a9-e50e24dcca9e',
            char_tx_UUID='6e400003-b5a3-f393-e0a9-e50e24dcca9e',
            mtu=20
        )


class USBPUPConnection(PybricksPUPProtocol, USBConnection):

    def __init__(self):
        """Initialize."""

        super().__init__()


class USBRPCConnection(CharacterGlue, USBConnection):

    def __init__(self, **kwargs):
        self.m_data = [{}] * 20
        self.i_data = []
        self.log_file = None
        super().__init__(EOL=b'\r', **kwargs)

    def user_line_handler(self, line):

        if 'PB_OF' in line:
            if self.log_file is not None:
                raise OSError("Log file is already open!")
            name = line[6:]
            self.logger.info("Saving log to {0}.".format(name))
            self.log_file = open(name, 'w')
            return

        if 'PB_EOF' in line:
            if self.log_file is None:
                raise OSError("No log file is currently open!")
            self.logger.info("Done saving log.")
            self.log_file.close()
            self.log_file = None
            return

        if self.log_file is not None:
            print(line, file=self.log_file)
            return

        print(line)

    def line_handler(self, line):
        try:
            data = json.loads(line)
            if 'e' in data:
                print(base64.b64decode(data['e']))
            elif 'm' in data:
                if type(data['m']) == int:
                    self.m_data[data['m']] = data
                elif data['m'] == 'runtime_error':
                    print(base64.b64decode(data['p'][3]))
                elif data['m'] == 'userProgram.print':
                    self.user_line_handler(base64.b64decode(data['p']['value']).decode('ascii').strip())
                else:
                    print("unknown", data)
            else:
                self.i_data.append(data)
        except json.JSONDecodeError:
            pass

    async def send_dict(self, command):
        await self.write(json.dumps(command).encode('ascii') + b'\r')

    async def send_command(self, message, payload):

        data_id = ''
        for i in range(4):
            c = chr(random.randint(ord('A'), ord('Z')))
            data_id += c

        data = {
            'i': data_id,
            'm': message,
            'p': payload
        }

        await self.send_dict(data)
        return data_id

    async def send_command_and_get_response(self, message, payload):

        data_id = await self.send_command(message, payload)
        response = None

        for i in range(30):

            while len(self.i_data) > 0:
                data = self.i_data.pop(0)
                if data['i'] == data_id:
                    response = data
                    break

            if response is not None:
                return response['r']
            else:
                await asyncio.sleep(0.1)

    async def run(self, py_path, wait=False):
        response = await self.send_command_and_get_response("program_modechange", {
                "mode": "download"
            })

        with open(py_path, 'rb') as demo:
            program = demo.read()

        chunk_size = 512
        chunks = [program[i:i+chunk_size] for i in range(0, len(program), chunk_size)]

        while response is None or 'transferid' not in response:
            response = await self.send_command_and_get_response("start_write_program", {
                        "meta": {
                            "created": 0,
                            "modified": 0,
                            "project_id": "Pybricksdev_",
                            "project_id": "Pybricksdev_",
                            "name": "Pybricksdev_____",
                            "type": "python"
                        },
                        "size": len(program),
                        "slotid": 0
                    })
        transferid = response['transferid']
        for i, chunk in enumerate(chunks):
            response = await self.send_command_and_get_response("write_package", {
                        "data": base64.b64encode(chunk).decode('ascii'),
                        "transferid": transferid
                    })
            print("Sending: {0}%".format(int((i+1)/len(chunks) * 100)))
        await asyncio.sleep(0.5)
        response = await self.send_command_and_get_response("program_execute", {
                    "slotid": 0
                })
        print(response)


class EV3Connection():
    """ev3dev SSH connection for running pybricks-micropython scripts.

    This wraps convenience functions around the asyncssh client.
    """

    _HOME = '/home/robot'
    _USER = 'robot'
    _PASSWORD = 'maker'

    def abs_path(self, path):
        return os.path.join(self._HOME, path)

    async def connect(self, address):
        """Connects to ev3dev using SSH with a known IP address.

        Arguments:
            address (str):
                IP address of the EV3 brick running ev3dev.

        Raises:
            OSError:
                Connect failed.
        """

        print("Connecting to", address, "...", end=" ")
        self.client = await asyncssh.connect(
            address, username=self._USER, password=self._PASSWORD
        )
        print("Connected.", end=" ")
        self.client.sftp = await self.client.start_sftp_client()
        await self.client.sftp.chdir(self._HOME)
        print("Opened SFTP.")

    async def beep(self):
        """Makes the EV3 beep."""
        await self.client.run('beep')

    async def disconnect(self):
        """Closes the connection."""
        self.client.sftp.exit()
        self.client.close()

    async def download(self, local_path):
        """Downloads a file to the EV3 Brick using sftp.

        Arguments:
            local_path (str):
                Path to the file to be downloaded. Relative to current working
                directory. This same tree will be created on the EV3 if it
                does not already exist.
        """
        # Compute paths
        dirs, file_name = os.path.split(local_path)

        # Make sure same directory structure exists on EV3
        if not await self.client.sftp.exists(self.abs_path(dirs)):
            # If not, make the folders one by one
            total = ''
            for name in dirs.split(os.sep):
                total = os.path.join(total, name)
                if not await self.client.sftp.exists(self.abs_path(total)):
                    await self.client.sftp.mkdir(self.abs_path(total))

        # Send script to EV3
        remote_path = self.abs_path(local_path)
        await self.client.sftp.put(local_path, remote_path)
        return remote_path

    async def run(self, local_path, wait=True):
        """Downloads and runs a Pybricks MicroPython script.

        Arguments:
            local_path (str):
                Path to the file to be downloaded. Relative to current working
                directory. This same tree will be created on the EV3 if it
                does not already exist.
            wait (bool):
                Whether to wait for any output until the program completes.
        """

        # Send script to the hub
        remote_path = await self.download(local_path)

        # Run it and return stderr to get Pybricks MicroPython output
        print("Now starting:", remote_path)
        prog = 'brickrun -r -- pybricks-micropython {0}'.format(remote_path)

        # Run process asynchronously and print output as it comes in
        async with self.client.create_process(prog) as process:
            # Keep going until the process is done
            while process.exit_status is None and wait:
                try:
                    line = await asyncio.wait_for(
                        process.stderr.readline(), timeout=0.1
                    )
                    print(line.strip())
                except asyncio.TimeoutError:
                    pass

    async def get(self, remote_path, local_path=None):
        """Gets a file from the EV3 over sftp.

        Arguments:
            remote_path (str):
                Path to the file to be fetched. Relative to ev3 home directory.
            local_path (str):
                Path to save the file. Defaults to same as remote_path.
        """
        if local_path is None:
            local_path = remote_path
        await self.client.sftp.get(
            self.abs_path(remote_path), localpath=local_path
        )
