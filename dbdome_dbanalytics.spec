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

def _meta(*names):
    # Bundle metadata for whichever distribution name is actually installed
    # (e.g. psycopg2 vs psycopg2-binary); skip cleanly if none is present.
    for n in names:
        try:
            return copy_metadata(n)
        except Exception:
            continue
    return []

# Build stamp written by build.ps1 (utils/version.py reads it to report
# 2.01.<Build_No>). Absent in an ad-hoc `pyinstaller` run, and that is on
# purpose: no stamp means the binary reports build 000, which is how you spot a
# build that did not come through the versioned process.
VERSION_STAMP = (
    [('utils/version_build.json', 'utils')]
    if os.path.isfile('utils/version_build.json') else []
)

META_DATAS = (
    _meta('numpy')
    + _meta('python-dateutil')
    + _meta('sqlalchemy', 'SQLAlchemy')
    + _meta('psycopg2', 'psycopg2-binary')
    + _meta('pymysql', 'PyMySQL')
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

# psycopg2-binary (delvewheel-packaged) places its native DLLs (libpq, libssl,
# libcrypto) in a sibling folder psycopg2_binary.libs/ and adds it via
# os.add_dll_directory() in psycopg2/__init__.py. PyInstaller never copies that
# folder, so _psycopg.pyd fails with "DLL load failed" at runtime. Bundle the
# DLLs into the same relative path the delvewheel patch expects.
_PSYCOPG2_LIBS_SRC = os.path.join(sys.prefix, 'Lib', 'site-packages', 'psycopg2_binary.libs')
PSYCOPG2_BINS = [
    (_dll, 'psycopg2_binary.libs')
    for _dll in _glob.glob(os.path.join(_PSYCOPG2_LIBS_SRC, '*.dll'))
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
# Dead modules that import heavy, unused ML libs (torch / sentence-transformers).
# They are not referenced at runtime, so we drop them from the bundle and exclude
# their libraries to keep the build small/fast.
_SKIP_MODULES = {'ai.Autoencoder_v1', 'analysis.analyse_threats'}
EXCLUDES = ['torch', 'sentence_transformers', 'transformers']

PROJECT_HIDDEN = []
for _pkg in PROJECT_PACKAGES:
    PROJECT_HIDDEN += [m for m in collect_submodules(_pkg) if m not in _SKIP_MODULES]

a = Analysis(
    ['dbdome_main.py'],
    pathex=['.', PYWIN32_LIB],
    binaries=PYWIN32_SYS32_BINS + PYTZ_BINARIES,
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
        ('icons', 'icons'),
        ('sql_scripts', 'sql_scripts'),
        ('scripts/oracle_verification_queries.json', 'scripts'),
        ('.env', '.'),
    ] + VERSION_STAMP + META_DATAS + PYTZ_DATAS,
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
        # psycopg2/__init__.py never imports .errors statically - the binding is
        # made inside the compiled _psycopg, which the analyzer cannot follow.
        # Without this the submodule is absent from the PYZ and every
        # `except psycopg2.errors.X` raises AttributeError while handling the
        # original exception (seen live: ddl_audit_scanner failing every 2 min).
        'psycopg2.errors',
        'psycopg2.extras',
        'pyodbc',
        'oracledb',
        'pymysql',
        'sqlalchemy',
        'pandas',
        'numpy',
        # pymongo is imported lazily inside processes/mongo_shim.connect_mongodb so
        # the driver cost stays off every non-Mongo collector; a lazy import is
        # invisible to PyInstaller's static analysis, hence the explicit entry.
        'pymongo',
        'bson',
        'dns',              # pymongo needs dnspython to resolve mongodb+srv:// URIs
        # LDAP test-connection in utils/ldap_settings.py imports ldap3 lazily,
        # so PyInstaller can't see it from the module graph.
        'ldap3',
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
    excludes=EXCLUDES,
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
        ('sql_scripts', 'sql_scripts'),
        ('scripts/oracle_verification_queries.json', 'scripts'),
        ('.env', '.'),
    ] + VERSION_STAMP + META_DATAS + PYTZ_DATAS,
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
        # psycopg2/__init__.py never imports .errors statically - the binding is
        # made inside the compiled _psycopg, which the analyzer cannot follow.
        # Without this the submodule is absent from the PYZ and every
        # `except psycopg2.errors.X` raises AttributeError while handling the
        # original exception (seen live: ddl_audit_scanner failing every 2 min).
        'psycopg2.errors',
        'psycopg2.extras',
        'pyodbc',
        'oracledb',
        'pymysql',
        'sqlalchemy',
        'pandas',
        'numpy',
        # pymongo is imported lazily inside processes/mongo_shim.connect_mongodb so
        # the driver cost stays off every non-Mongo collector; a lazy import is
        # invisible to PyInstaller's static analysis, hence the explicit entry.
        'pymongo',
        'bson',
        'dns',              # pymongo needs dnspython to resolve mongodb+srv:// URIs
        # LDAP test-connection in utils/ldap_settings.py imports ldap3 lazily,
        # so PyInstaller can't see it from the module graph.
        'ldap3',
        'win32serviceutil',
        'win32service',
        'win32event',
        'servicemanager',
        'win32api',
        'win32timezone',
        'pywintypes',
    ] + PROJECT_HIDDEN + PYTZ_HIDDENIMPORTS,
    hookspath=[],
    excludes=EXCLUDES,
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
