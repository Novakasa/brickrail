# SPDX-License-Identifier: MIT
# Copyright (c) 2019-2020 The Pybricks Authors

import io
from collections import namedtuple
import json
import os
import struct
import sys
from typing import Dict, Tuple
from tqdm import tqdm
import typing
import zipfile

from .ble import BLERequestsConnection
from .compile import save_script, compile_file
from .hubs import HubTypeId


def sum_complement(fw, max_size):
    """Calculates the checksum of a firmware file using the sum complement
    method of adding each 32-bit word and the returning the two's complement
    as the checksum.

    Arguments:
        fw (file):
            The firmware file (a binary buffer - e.g. a file opened in 'rb' mode)
        max_size (int):
            The maximum size of the firmware file.

    Returns:
        int: The correction needed to make the checksum of the file == 0.
    """
    checksum = 0
    size = 0

    while True:
        word = fw.read(4)
        if not word:
            break
        checksum += struct.unpack('I', word)[0]
        size += 4

    if size > max_size:
        print('firmware + main.mpy is too large"', file=sys.stderr)
        exit(1)

    for _ in range(size, max_size, 4):
        checksum += 0xffffffff

    checksum &= 0xffffffff
    correction = checksum and (1 << 32) - checksum or 0

    return correction


# thanks https://stackoverflow.com/a/33152544/1976323

_CRC_TABLE = (
    0x00000000,
    0x04C11DB7,
    0x09823B6E,
    0x0D4326D9,
    0x130476DC,
    0x17C56B6B,
    0x1A864DB2,
    0x1E475005,
    0x2608EDB8,
    0x22C9F00F,
    0x2F8AD6D6,
    0x2B4BCB61,
    0x350C9B64,
    0x31CD86D3,
    0x3C8EA00A,
    0x384FBDBD,
)


def _dword(value):
    return value & 0xFFFFFFFF


def _crc32_fast(crc, data):
    crc, data = _dword(crc), _dword(data)
    crc ^= data
    for _ in range(8):
        crc = _dword(crc << 4) ^ _CRC_TABLE[crc >> 28]
    return crc


def _crc32_fast_block(crc, buffer):
    for data in buffer:
        crc = _crc32_fast(crc, data)
    return crc


def crc32_checksum(fw, max_size):
    """Calculate the checksum of a firmware file using CRC-32 as implemented
    in STM32 microprocessors.

    Parameters
    ----------
    fw : file
        The firmware file (a binary buffer - e.g. a file opened in 'rb' mode)
    max_size : int
        The maximum size of the firmware file.

    Returns
    -------
    int
        The checksum
    """

    # remove the last 4 bytes that are the placeholder for the checksum
    try:
        fw = fw.read()[:-4]
    except AttributeError:
        fw = fw[:-4]
    if len(fw) + 4 > max_size:
        raise ValueError("File is too large")

    if len(fw) & 3:
        raise ValueError("bytes_data length must be multiple of four")

    crc = 0xFFFFFFFF
    for index in range(0, len(fw), 4):
        data = int.from_bytes(fw[index:index + 4], "little")
        crc = _crc32_fast(crc, data)
    return crc


async def create_firmware(firmware_zip: typing.Union[str, os.PathLike, typing.BinaryIO]) -> Tuple[bytes, dict]:
    """Creates a firmware blob from base firmware and main.mpy file.

    Arguments:
        firmware_zip:
            Path to the firmware zip file or a file-like object.

    Returns:
        bytes: Composite binary blob with correct padding and checksum.
        dict: Meta data for this firmware file.
    """

    archive = zipfile.ZipFile(firmware_zip)
    base = archive.open('firmware-base.bin').read()
    main_py = io.TextIOWrapper(archive.open('main.py'))
    metadata = json.load(archive.open('firmware.metadata.json'))

    mpy = await compile_file(
        save_script(main_py.read()),
        metadata['mpy-cross-options'],
        metadata['mpy-abi-version']
    )

    # start with base firmware binary blob
    firmware = bytearray(base)
    # pad with 0s until user-mpy-offset
    firmware.extend(
        0 for _ in range(metadata['user-mpy-offset'] - len(firmware)))
    # append 32-bit little-endian main.mpy file size
    firmware.extend(struct.pack('<I', len(mpy)))
    # append main.mpy file
    firmware.extend(mpy)
    # pad with 0s to align to 4-byte boundary
    firmware.extend(0 for _ in range(-len(firmware) % 4))

    # append 32-bit little-endian checksum
    if metadata['checksum-type'] == "sum":
        firmware.extend(
            struct.pack(
                '<I',
                sum_complement(io.BytesIO(firmware),
                               metadata['max-firmware-size'] - 4)))
    elif metadata['checksum-type'] == "crc32":
        firmware.extend(
            struct.pack(
                '<I',
                crc32_checksum(io.BytesIO(firmware),
                               metadata['max-firmware-size'] - 4)))
    else:
        print(f'Unknown checksum type "{metadata["checksum-type"]}"',
              file=sys.stderr)
        exit(1)

    return firmware, metadata


# NAME, PAYLOAD_SIZE requirement
HUB_INFO: Dict[HubTypeId, Tuple[str, int]] = {
    HubTypeId.MOVE_HUB: ('Move Hub', 14),
    HubTypeId.CITY_HUB: ('City Hub', 32),
    HubTypeId.TECHNIC_HUB: ('Technic Hub', 32),
}


class BootloaderRequest():
    """Bootloader request structure."""

    def __init__(self, command, name, request_format, data_format, request_reply=True, write_with_response=True):
        self.command = command
        self.ReplyClass = namedtuple(name, request_format)
        self.data_format = data_format
        self.reply_len = struct.calcsize(data_format)
        if request_reply:
            self.reply_len += 1
        self.write_with_response = write_with_response

    def make_request(self, payload=None):
        request = bytearray((self.command,))
        if payload is not None:
            request += payload
        return request

    def parse_reply(self, reply):
        if reply[0] == self.command:
            return self.ReplyClass(*struct.unpack(self.data_format, reply[1:]))
        else:
            raise ValueError("Unknown message: {0}".format(reply))


class BootloaderConnection(BLERequestsConnection):
    """Connect to Powered Up Hub Bootloader and update firmware."""

    # Static BootloaderRequest instances for particular messages
    ERASE_FLASH = BootloaderRequest(
        0x11, 'Erase', ['result'], '<B'
    )
    PROGRAM_FLASH_BARE = BootloaderRequest(
        0x22, 'Flash', [], '', False, False
    )
    PROGRAM_FLASH = BootloaderRequest(
        0x22, 'Flash', ['checksum', 'count'], '<BI', True, False
    )
    START_APP = BootloaderRequest(
        0x33, 'Start', [], '', False, False
    )
    INIT_LOADER = BootloaderRequest(
        0x44, 'Init', ['result'], '<B'
    )
    GET_INFO = BootloaderRequest(
        0x55, 'Info', ['version', 'start_addr', 'end_addr', 'type_id'], '<iIIB'
    )
    GET_CHECKSUM = BootloaderRequest(
        0x66, 'Checksum', ['checksum'], '<B'
    )
    GET_FLASH_STATE = BootloaderRequest(
        0x77, 'State', ['level'], '<B'
    )
    DISCONNECT = BootloaderRequest(
        0x88, 'Disconnect', [], '', False, False
    )

    def __init__(self):
        """Initialize the BLE Connection for Bootloader service."""
        super().__init__('00001626-1212-efde-1623-785feabcd123')

    async def bootloader_request(self, request, payload=None, delay=0.05, timeout=None):
        """Sends a message to the bootloader and awaits corresponding reply."""

        # Get message command and expected reply length
        self.logger.debug("Clear and prepare reply")
        self.prepare_reply()

        # Write message
        self.logger.debug("Make and write request")
        data = request.make_request(payload)
        await self.write(data, delay, request.write_with_response)

        # If we expect a reply, await for it
        if request.reply_len > 0:
            self.logger.debug("Awaiting reply")
            reply = await self.wait_for_reply(timeout)
            return request.parse_reply(reply)

    async def flash(self, firmware, metadata, delay):

        # Firmware information
        firmware_io = io.BytesIO(firmware)
        firmware_size = len(firmware)

        # Request hub information
        self.logger.debug("Getting device info.")
        info = await self.bootloader_request(self.GET_INFO)
        self.logger.debug(info)

        # Hub specific settings
        hub_name, max_data_size = HUB_INFO[info.type_id]

        # Verify hub ID against ID in firmware package
        if info.type_id != metadata['device-id']:
            await self.disconnect()
            raise RuntimeError(
                "This firmware {0}, but we are connected to {1}.".format(
                    HUB_INFO[metadata['device-id']][0], hub_name
                )
            )

        # Erase existing firmware
        self.logger.debug("Erasing flash.")
        response = await self.bootloader_request(self.ERASE_FLASH)
        self.logger.debug(response)

        # Get the bootloader ready to accept the firmware
        self.logger.debug('Request begin update.')
        response = await self.bootloader_request(
            request=self.INIT_LOADER,
            payload=struct.pack('<I', firmware_size)
        )
        self.logger.debug(response)
        self.logger.debug('Begin update.')

        # Percentage after which we'll check progress
        verify_progress = 5

        # Maintain progress using tqdm
        with tqdm(total=firmware_size, unit='B', unit_scale=True) as pbar:

            # Repeat until the whole firmware has been processed
            while firmware_io.tell() != firmware_size:

                # Progress percentage
                progress = firmware_io.tell() / firmware_size * 100

                # If progressed beyond next checkpoint, check connection.
                if progress > verify_progress:
                    # Get checksum. This tells us the hub is still operating
                    # normally. If we don't get it, we stop
                    result = await self.bootloader_request(
                        self.GET_CHECKSUM, timeout=2
                    )
                    self.logger.debug(result)

                    # Check again after 20% more progress
                    verify_progress += 20

                # The write address is the starting address plus
                # how much has been written already
                address = info.start_addr + firmware_io.tell()

                # Read the firmware chunk to be sent
                payload = firmware_io.read(max_data_size)

                # Check if this is the last chunk to be sent
                if firmware_io.tell() == firmware_size:
                    # If so, request flash with confirmation request.
                    request = self.PROGRAM_FLASH
                else:
                    # Otherwise, do not wait for confirmation.
                    request = self.PROGRAM_FLASH_BARE

                # Pack the data in the expected format
                data = struct.pack('<BI' + 'B' * len(payload), len(payload) + 4, address, *payload)
                response = await self.bootloader_request(request, data, delay)
                self.logger.debug(response)
                pbar.update(len(payload))

        # Reboot the hub
        self.logger.debug('Request reboot.')
        response = await self.bootloader_request(self.START_APP)
        self.logger.debug(response)
