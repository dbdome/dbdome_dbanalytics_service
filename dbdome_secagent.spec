# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for the security-agent sidecar.
#
# BUILD THIS WITH C:\apps\venv311_agent -- NOT venv314.
#     C:\apps\venv311_agent\Scripts\python.exe -m PyInstaller --clean --noconfirm \
#         --distpath dist_secagent --workpath build_secagent dbdome_secagent.spec
#
# That is the whole reason this is a separate artifact. llama-cpp-python
# publishes no distribution for Python 3.14, and build.ps1 hard-requires
# venv314 for the service, so the model cannot be loaded inside
# dbdome_service.exe. venv311_agent (Python 3.11.9) already carries
# llama_cpp 0.3.35, so the sidecar is frozen from there and the service
# talks to it over a pipe.
#
# The GGUF is deliberately NOT bundled: it is ~2.3 GB, identical across every
# install, and would bloat _internal and every ISO. It is provisioned into
# <install>\security_agent\models\ instead, and a missing model simply makes
# the agent fail open.

import os
import sys
import glob

block_cipher = None

# llama_cpp loads llama.dll / ggml*.dll through ctypes from its own lib/
# directory. ctypes loading is invisible to PyInstaller's static analysis, so
# without this the bundle ships the Python wrapper with no native library and
# every call dies with "Shared library with base name 'llama' not found" --
# the same failure mode already handled for psycopg2_binary.libs and
# pywin32_system32 in DBDOME_dbanalytics.spec.
_LLAMA_LIB = os.path.join(sys.prefix, 'Lib', 'site-packages', 'llama_cpp', 'lib')
LLAMA_BINARIES = [
    (dll, os.path.join('llama_cpp', 'lib'))
    for dll in glob.glob(os.path.join(_LLAMA_LIB, '*.dll'))
]

# Some llama_cpp releases keep the DLLs beside the package rather than in lib/.
_LLAMA_PKG = os.path.join(sys.prefix, 'Lib', 'site-packages', 'llama_cpp')
LLAMA_BINARIES += [
    (dll, 'llama_cpp')
    for dll in glob.glob(os.path.join(_LLAMA_PKG, '*.dll'))
]

a = Analysis(
    ['security_agent/sidecar_main.py'],
    pathex=['.'],
    binaries=LLAMA_BINARIES,
    datas=[],
    hiddenimports=[
        'llama_cpp',
        'llama_cpp.llama',
        'llama_cpp.llama_cpp',
        'llama_cpp.llama_chat_format',
        'llama_cpp._ctypes_extensions',
        'diskcache',      # llama_cpp's optional cache backend, imported lazily
        'jinja2',         # chat-template rendering
        'numpy',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    # The sidecar is intentionally minimal: it must not drag in the service's
    # database/reporting stack. Its only job is model in, JSON out.
    excludes=[
        'torch', 'sentence_transformers', 'transformers',
        'matplotlib', 'scipy', 'pandas', 'reportlab',
        'psycopg2', 'sqlalchemy', 'pyodbc', 'oracledb', 'pymongo',
        'fastapi', 'uvicorn', 'starlette',
    ],
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
    name='dbdome_secagent',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    # UPX is off across all DBDOME build outputs -- it has been observed to
    # corrupt small files in the bundle on some customer installs.
    upx=False,
    console=True,
    icon='icons/dbexpert.ico' if os.path.isfile('icons/dbexpert.ico') else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='dbdome_secagent',
)
