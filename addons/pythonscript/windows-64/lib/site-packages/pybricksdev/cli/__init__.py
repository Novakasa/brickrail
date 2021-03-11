# SPDX-License-Identifier: MIT
# Copyright (c) 2019-2020 The Pybricks Authors

"""Command line wrapper around pybricksdev library."""

import argparse
import asyncio
import logging
import sys
import validators

from abc import ABC, abstractmethod
from os import path

import argcomplete

from argcomplete.completers import ChoicesCompleter, FilesCompleter

from .. import __name__ as MODULE_NAME, __version__ as MODULE_VERSION
from ..hubs import HubTypeId


PROG_NAME = (f'{path.basename(sys.executable)} -m {MODULE_NAME}'
             if sys.argv[0].endswith('__main__.py') else path.basename(sys.argv[0]))


class Tool(ABC):
    """Common base class for tool implementations."""

    @abstractmethod
    def add_parser(self, subparsers: argparse._SubParsersAction):
        """
        Overriding methods must at least do the following::

            parser = subparsers.add_parser('tool', ...)
            parser.tool = self

        Then additional arguments can be added using the ``parser`` object.
        """
        pass

    @abstractmethod
    async def run(self, args: argparse.Namespace):
        """
        Overriding methods should provide an implementation to run the tool.
        """
        pass


def _parse_script_arg(script_arg):
    """Save user script argument to a file if it is a Python one-liner."""
    from ..compile import save_script

    if not path.exists(script_arg):
        return save_script(script_arg)
    return script_arg


class Compile(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'compile',
            help='compile a Pybricks program without running it',
        )
        parser.tool = self
        # The argument is a filename or a Python one-liner.
        parser.add_argument(
            'script',
            metavar='<script>',
            help='path to a MicroPython script or inline script',
        )

    async def run(self, args: argparse.Namespace):
        from ..compile import compile_file, print_mpy

        script_path = _parse_script_arg(args.script)

        # Compile the script and print the result
        mpy = await compile_file(script_path)
        print_mpy(mpy)


class Run(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'run',
            help='run a Pybricks program',
        )
        parser.tool = self
        parser.add_argument(
            'conntype',
            metavar='<connection type>',
            help='connection type: %(choices)s',
            choices=['ble', 'usb', 'ssh']
        )
        parser.add_argument(
            'device',
            metavar='<device>',
            help='hostname or IP address for SSH connection; '
                 'Bluetooth device name or Bluetooth address for BLE connection; '
                 'serial port name for USB connection',
        )
        parser.add_argument(
            'script',
            metavar='<script>',
            help='path to a MicroPython script or inline script',
        )
        parser.add_argument(
            '--wait',
            help='Await program completion (True) or disconnect immediately (False)',
            required=False,
            default='True',
            choices=['True', 'False']
        )

    async def run(self, args: argparse.Namespace):
        from ..ble import find_device
        from ..connections import BLEPUPConnection, EV3Connection, USBPUPConnection, USBRPCConnection

        # Convert script argument to valid path
        script_path = _parse_script_arg(args.script)

        # Pick the right connection
        if args.conntype == 'ssh':
            # So it's an ev3dev
            if not validators.ip_address.ipv4(args.device):
                raise ValueError("Device must be IP address.")
            hub = EV3Connection()
            device_or_address = args.device
        elif args.conntype == 'ble':
            # It is a Pybricks Hub with BLE. Device name or address is given.
            hub = BLEPUPConnection()
            hub.logger.setLevel(logging.INFO)
            if validators.mac_address(args.device):
                device_or_address = args.device
            else:
                device_or_address = await find_device(args.device, timeout=5)
        elif args.conntype == 'usb' and args.device == 'lego':
            # It's LEGO stock firmware Hub with USB.
            hub = USBRPCConnection()
            hub.logger.setLevel(logging.INFO)
            device_or_address = 'LEGO Technic Large Hub in FS Mode'
        elif args.conntype == 'usb':
            # It's a Pybricks Hub with USB. Port name is given.
            hub = USBPUPConnection()
            hub.logger.setLevel(logging.INFO)
            device_or_address = args.device
        else:
            raise ValueError(f"Unknown connection type: {args.conntype}")

        # Connect to the address and run the script
        await hub.connect(device_or_address)
        await hub.run(script_path, args.wait == 'True')
        await hub.disconnect()


class Flash(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'flash',
            help='flash firmware on a LEGO Powered Up device'
        )
        parser.tool = self
        parser.add_argument(
            'firmware',
            metavar='<firmware-file>',
            type=argparse.FileType(mode='rb'),
            help='the firmware .zip file',
        ).completer = FilesCompleter(allowednames=('.zip',))
        parser.add_argument(
            '-d',
            '--delay',
            dest='delay',
            metavar='<milliseconds>',
            type=int,
            default=10,
            help='delay between Bluetooth packets (default: %(default)i)',
        ).completer = ChoicesCompleter([5, 10, 15, 20])

    async def run(self, args: argparse.Namespace):
        from ..flash import create_firmware

        print('Creating firmware')
        firmware, metadata = await create_firmware(args.firmware)

        if metadata["device-id"] == HubTypeId.PRIME_HUB:
            from ..dfu import flash_dfu

            flash_dfu(firmware, metadata)
        else:
            from ..ble import find_device
            from ..flash import BootloaderConnection

            device = await find_device('LEGO Bootloader', 15)
            print('Found:', device)
            updater = BootloaderConnection()
            updater.logger.setLevel(logging.INFO)
            await updater.connect(device)
            print('Erasing flash and starting update')
            await updater.flash(firmware, metadata, args.delay/1000)


class DualBoot(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'dual-boot',
            help='Install Pybricks on the SPIKE Prime Hub and Inventor Hub, alongside the stock firmware.'
        )
        parser.tool = self
        parser.add_argument(
            'firmware',
            metavar='<firmware-file>',
            type=argparse.FileType(mode='rb'),
            help='the firmware .zip file',
        ).completer = FilesCompleter(allowednames=('.zip',))

    async def run(self, args: argparse.Namespace):
        from ..repl_installer import REPLDualBootInstaller
        installer = REPLDualBootInstaller()
        await installer.install(args.firmware.name)


class DFUBackup(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'backup',
            help='backup firmware using DFU'
        )
        parser.tool = self
        parser.add_argument(
            'firmware',
            metavar='<firmware-file>',
            type=argparse.FileType(mode='wb'),
            help='the firmware .bin file',
        ).completer = FilesCompleter(allowednames=('.bin',))

    async def run(self, args: argparse.Namespace):
        from ..dfu import backup_dfu

        backup_dfu(args.firmware)


class DFURestore(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            'restore',
            help='restore firmware using DFU',
        )
        parser.tool = self
        parser.add_argument(
            'firmware',
            metavar='<firmware-file>',
            type=argparse.FileType(mode='rb'),
            help='the firmware .bin file',
        ).completer = FilesCompleter(allowednames=('.bin',))

    async def run(self, args: argparse.Namespace):
        from ..dfu import restore_dfu

        restore_dfu(args.firmware)


class DFU(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            "dfu",
            help="use DFU to backup or restore firmware",
        )
        parser.tool = self
        self.subparsers = parser.add_subparsers(
            metavar="<action>",
            dest="action",
            help="the action to perform"
        )

        for tool in DFUBackup(), DFURestore():
            tool.add_parser(self.subparsers)

    def run(self, args: argparse.Namespace):
        return self.subparsers.choices[args.action].tool.run(args)


class Udev(Tool):
    def add_parser(self, subparsers: argparse._SubParsersAction):
        parser = subparsers.add_parser(
            "udev",
            help="print udev rules to stdout"
        )
        parser.tool = self

    async def run(self, args: argparse.Namespace):
        from importlib.resources import read_text
        from .. import resources

        print(read_text(resources, resources.UDEV_RULES))


def main():
    """Runs ``pybricksdev`` command line interface."""

    # Provide main description and help.
    parser = argparse.ArgumentParser(
        prog=PROG_NAME,
        description='Utilities for Pybricks developers.',
        epilog='Run `%(prog)s <tool> --help` for tool-specific arguments.',
    )

    parser.add_argument('-v', '--version', action='version', version=f'{MODULE_NAME} v{MODULE_VERSION}')

    subparsers = parser.add_subparsers(
        metavar='<tool>',
        dest='tool',
        help='the tool to use',
    )

    for tool in Compile(), Run(), Flash(), DualBoot(), DFU(), Udev():
        tool.add_parser(subparsers)

    argcomplete.autocomplete(parser)
    args = parser.parse_args()

    if not args.tool:
        parser.error(f'Missing name of tool: {"|".join(subparsers.choices.keys())}')

    loop = asyncio.get_event_loop()
    loop.run_until_complete(subparsers.choices[args.tool].tool.run(args))
