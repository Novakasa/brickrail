import sys
from . import run

sys.exit(run(*sys.argv[1:]).wait())