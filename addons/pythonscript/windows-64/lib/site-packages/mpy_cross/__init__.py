import os
import stat
import subprocess
from glob import glob
from os.path import join, dirname, abspath

__all__ = ['mpy_cross', 'run']

mpy_cross = abspath(glob(join(dirname(__file__), 'mpy-cross*'))[0])


def run(*args, **kwargs):
    try:
        st = os.stat(mpy_cross)
        os.chmod(mpy_cross, st.st_mode | stat.S_IEXEC)
    except OSError:
        pass

    return subprocess.Popen([mpy_cross] + list(args), **kwargs)
