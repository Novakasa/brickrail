# SPDX-License-Identifier: MIT
# Copyright (c) 2019-2020 The Pybricks Authors

import os
from pathlib import Path
import mpy_cross
import asyncio

BUILD_DIR = "build"
TMP_PY_SCRIPT = "_tmp.py"
TMP_MPY_SCRIPT = "_tmp.mpy"


def make_build_dir():
    # Create build folder if it does not exist
    if not os.path.exists(BUILD_DIR):
        os.mkdir(BUILD_DIR)

    # Raise error if there happens to be a file by this name
    if os.path.isfile(BUILD_DIR):
        raise OSError("A file named build already exists.")


async def run_mpy_cross(args):
    """Runs mpy-cross asynchronously with given arguments.

    Arguments:
        args:
            Arguments to pass to mpy-cross.

    Returns:
        str: stdout.

    Raises:
        OSError with stderr if mpy-cross fails.

    """

    # Run the process asynchronously
    proc = await asyncio.create_subprocess_exec(
        mpy_cross.mpy_cross, *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE)

    # Check the output for compile errors such as syntax errors
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise ValueError(stderr.decode())

    # On success, return stdout
    return stdout.decode()


async def compile_file(path, compile_args=["-mno-unicode"], mpy_version=None):
    """Compiles a Python file with mpy-cross and return as bytes.

    Arguments:
        path (str):
            Path to script that is to be compiled.
        compile_args (dict):
            Extra arguments for mpy-cross.
        mpy_version (int):
            Expected mpy ABI version.

    Returns:
        bytes: compiled script in mpy format.

    Raises:
        OSError with stderr if mpy-cross fails.
        OSError if mpy-cross ABI version does not match packaged version.
    """

    # Get version info
    out = await run_mpy_cross(["--version"])
    installed_mpy_version = int(out.strip()[-1])
    if mpy_version is not None and installed_mpy_version != mpy_version:
        raise OSError(
            "Expected mpy-cross ABI v{0} but v{1} is installed.".format(
                mpy_version, installed_mpy_version
            )
        )

    # Make the build directory
    make_build_dir()

    # Cross-compile Python file to .mpy and raise errors if any
    mpy_path = os.path.join(BUILD_DIR, Path(path).stem + ".mpy")
    await run_mpy_cross([path] + compile_args + ["-o", mpy_path])

    # Read the .mpy file and return as bytes
    with open(mpy_path, "rb") as mpy:
        return mpy.read()


def save_script(py_string):
    """Save a MicroPython one-liner to a file."""
    # Make the build directory.
    make_build_dir()

    # Path to temporary file.
    py_path = os.path.join(BUILD_DIR, TMP_PY_SCRIPT)

    # Write Python command to a file.
    with open(py_path, "w") as f:
        f.write(py_string + "\n")

    # Return path to file
    return py_path


def print_mpy(data):
    # Print as string as a sanity check.
    print("\nBytes:")
    print(data)

    # Print the bytes as a C byte array for development of new MicroPython
    # ports without usable I/O, REPL or otherwise.
    WIDTH = 8
    print(
        "\n// MPY file. Version: {0}. Size: {1}".format(data[1], len(data))
        + "\nconst uint8_t script[] = "
    )
    for i in range(0, len(data), WIDTH):
        chunk = data[i:i + WIDTH]
        hex_repr = ["0x{0}".format(hex(i)[2:].zfill(2).upper()) for i in chunk]
        print("    " + ", ".join(hex_repr) + ",")
    print("};")
