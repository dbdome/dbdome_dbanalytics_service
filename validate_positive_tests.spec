# -*- mode: python ; coding: utf-8 -*-
#
# Build the positive-test validation runner as a one-file exe.
#
#   pyinstaller validate_positive_tests.spec --distpath scripts/dist
#
# Run from the repo root so pathex='.' resolves the `utils` package. At runtime
# the exe reads `.env` AND `positive_tests_sqlserver.sql` from its OWN folder
# (dirname(sys.executable)); it uses the OS "ODBC Driver 1x for SQL Server".

a = Analysis(
    ['scripts/validate_positive_tests.py'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=['psycopg2', 'pyodbc', 'utils.config_dotenv'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='validate_positive_tests',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
