# -*- mode: python ; coding: utf-8 -*-


block_cipher = None

import sys
from pathlib import Path
site_packages = Path(next(p for p in sys.path if 'site-packages' in p))
binaries = [(str(site_packages / "mpy_cross_v6/mpy-cross"), "mpy_cross_v6/")]

a = Analysis(
    ['ble-server/ble_server.py'],
    pathex=[],
    binaries=binaries,
    datas=[('ble-server/hub_programs/', 'hub_programs/')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='ble_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='ble-server-macos',
)
