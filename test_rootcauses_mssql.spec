# -*- mode: python ; coding: utf-8 -*-
#
# Build the SQL Server root-cause detection test harness as a one-file exe.
#
#   pyinstaller test_rootcauses_mssql.spec --distpath scripts/dist
#
# Run from the repo root so pathex='.' resolves the `utils` package. The exe
# reads `.env` from its own folder (dirname(sys.executable)) at runtime, and
# uses the OS-installed "ODBC Driver 1x for SQL Server" via pyodbc.

a = Analysis(
    ['scripts/test_rootcauses_mssql.py'],
    pathex=['.'],                       # repo root — lets PyInstaller find utils.config_dotenv
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
    name='test_rootcauses_mssql',
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
