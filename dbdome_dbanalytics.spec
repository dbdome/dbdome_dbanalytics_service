# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for DBDOME dbanalytics service
# Build: pyinstaller dbdome_dbanalytics.spec

import os, sys
from PyInstaller.utils.hooks import collect_submodules, copy_metadata, collect_all

block_cipher = None

# pandas calls importlib.metadata.version() on its deps at import time; without
# the dist-info bundled, that lookup raises "Can't determine version for <pkg>".
# pytz is required (loaded at `import pandas`); the rest are optional deps that
# pandas version-checks lazily — bundle metadata for the ones we actually use to
# avoid a runtime ImportError the first time pandas touches them.
#
# pytz uses collect_all rather than copy_metadata because some customer builds
# shipped without the metadata folder being picked up (build-environment
# variance — UPX, AV scrubbing, copy bugs). collect_all bundles metadata,
# submodules, and tzdata files atomically, removing single-file failure modes.
PYTZ_DATAS, PYTZ_BINARIES, PYTZ_HIDDENIMPORTS = collect_all('pytz')

META_DATAS = (
    copy_metadata('numpy')
    + copy_metadata('python-dateutil')
    + copy_metadata('sqlalchemy')
    + copy_metadata('psycopg2')
    + copy_metadata('pymysql')
)

# pywin32 ships win32timezone in site-packages\win32\lib and exposes it via a
# .pth file. PyInstaller does not honor .pth files when resolving hidden
# imports, so without this path on pathex the module silently fails to bundle.
PYWIN32_LIB = os.path.join(sys.prefix, 'Lib', 'site-packages', 'win32', 'lib')

# pywintypes/pythoncom load their core DLLs (pywintypesXX.dll, pythoncomXX.dll)
# via a custom system-module loader, not normal Python imports. PyInstaller's
# static analysis misses them, so the bundled pywin32_system32/ folder ends up
# empty and `import win32serviceutil` blows up at runtime with
# "Module 'pywintypes' isn't in frozen sys.path". Force-bundle them as binaries
# into the same pywin32_system32/ subfolder the loader searches.
import glob as _glob
_PYWIN32_SYS32_SRC = os.path.join(sys.prefix, 'Lib', 'site-packages', 'pywin32_system32')
PYWIN32_SYS32_BINS = [
    (_dll, 'pywin32_system32')
    for _dll in _glob.glob(os.path.join(_PYWIN32_SYS32_SRC, '*.dll'))
]

# Force-include every submodule of the project's own packages. APScheduler /
# job_operation_scheduler.get_function_by_name resolves modules dynamically by
# string name, which PyInstaller's static analyzer does not catch reliably —
# especially `collection.mssql.monitoring_metrics_mssql_generic_query` and its
# vendor siblings. collect_submodules walks the package on disk and lists every
# .py file as a hidden import, so nothing is missed.
PROJECT_PACKAGES = [
    'collection',
    'analysis',
    'widgets',
    'jobs',
    'processes',
    'utils',
    'email_utils',
    'siem',
    'alerts',
    'authentication',
    'metrics_api',
    'print_utils',
    'advisories',
    'ai',
    'certification',
    'config',
    'ssrs',
    'synch',
    'ReportGenerator',
]
PROJECT_HIDDEN = []
for _pkg in PROJECT_PACKAGES:
    PROJECT_HIDDEN += collect_submodules(_pkg)

a = Analysis(
    ['dbdome_main.py'],
    pathex=['.', PYWIN32_LIB],
    binaries=PYWIN32_SYS32_BINS + PYTZ_BINARIES,
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
        ('icons', 'icons'),
        ('.env', '.'),
    ] + META_DATAS + PYTZ_DATAS,
    hiddenimports=[
        'http_server',
        'job_operation_scheduler',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'fastapi',
        'starlette',
        'apscheduler',
        'apscheduler.schedulers.background',
        'apscheduler.triggers.interval',
        'psycopg2',
        'pyodbc',
        'oracledb',
        'pymysql',
        'sqlalchemy',
        'pandas',
        'numpy',
        'win32serviceutil',
        'win32service',
        'win32event',
        'servicemanager',
        'win32api',
        'win32timezone',
        'pywintypes',
    ] + PROJECT_HIDDEN + PYTZ_HIDDENIMPORTS,
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

# Main console exe.
# UPX is disabled across all build outputs: it has been observed to corrupt
# tiny dist-info files (notably pytz) on some customer Windows installs,
# leading to "Can't determine version of pytz" at startup. The size win
# isn't worth the bundle-integrity risk.
exe_main = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='dbdome_dbanalytics',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    icon='icons/dbdome.ico',
)

# Service exe (separate entry point)
a_svc = Analysis(
    ['dbdome_service.py'],
    pathex=['.', PYWIN32_LIB],
    binaries=PYWIN32_SYS32_BINS + PYTZ_BINARIES,
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
        ('icons', 'icons'),
        ('.env', '.'),
    ] + META_DATAS + PYTZ_DATAS,
    hiddenimports=[
        'dbdome_main',
        'http_server',
        'job_operation_scheduler',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'fastapi',
        'starlette',
        'apscheduler',
        'apscheduler.schedulers.background',
        'apscheduler.triggers.interval',
        'psycopg2',
        'pyodbc',
        'oracledb',
        'pymysql',
        'sqlalchemy',
        'pandas',
        'numpy',
        'win32serviceutil',
        'win32service',
        'win32event',
        'servicemanager',
        'win32api',
        'win32timezone',
        'pywintypes',
    ] + PROJECT_HIDDEN + PYTZ_HIDDENIMPORTS,
    hookspath=[],
    excludes=[],
    cipher=block_cipher,
    noarchive=False,
)

pyz_svc = PYZ(a_svc.pure, a_svc.zipped_data, cipher=block_cipher)

exe_svc = EXE(
    pyz_svc,
    a_svc.scripts,
    [],
    exclude_binaries=True,
    name='dbdome_service',
    debug=False,
    strip=False,
    upx=False,
    console=True,
    icon='icons/dbdome.ico',
)

coll = COLLECT(
    exe_main,
    a.binaries,
    a.zipfiles,
    a.datas,
    exe_svc,
    a_svc.binaries,
    a_svc.zipfiles,
    a_svc.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='dbdome_dbanalytics',
)
