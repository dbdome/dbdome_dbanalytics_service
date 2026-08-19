"""DBDOME product version - the single source of truth for 2.MINOR.BUILD.

MAJOR/MINOR live here in source and change only on a product decision. BUILD is
supplied per build: build.ps1 prompts for it (pre-filling last+1), writes
``version_build.json`` next to this file, and the spec bundles that file into
the exe. A dev checkout with no such file reports build 0, which is how you can
tell "ran from source" from "ran a real build" at a glance.

Read order:
  1. DBDOME_BUILD_NO in the environment  (override for a one-off / CI run)
  2. version_build.json bundled beside the code or next to the exe
  3. 0  (dev fallback)

At service startup ``register()`` writes the running version into
config.app_version (7440), which is what the dashboards and the About panel
read. That ordering matters: the table then describes the binary that is
actually running, not merely the last one somebody built.
"""
import json
import os
import sys

VERSION_MAJOR = 2
VERSION_MINOR = 2

_BUILD_FILE = "version_build.json"


def _candidate_dirs():
    """Where version_build.json may sit: beside this module in a dev checkout,
    inside _internal when frozen, and next to the exe so a build number can be
    corrected in the field without a rebuild."""
    here = os.path.dirname(os.path.abspath(__file__))
    dirs = [here, os.path.dirname(here)]
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        dirs.append(meipass)
    if getattr(sys, "frozen", False):
        dirs.append(os.path.dirname(sys.executable))
    return dirs


def _read_build_file():
    for d in _candidate_dirs():
        p = os.path.join(d, _BUILD_FILE)
        if os.path.isfile(p):
            try:
                # utf-8-sig, not utf-8: PowerShell 5.1's Set-Content -Encoding utf8
                # always writes a BOM, and json.load rejects it. Reading it as
                # plain utf-8 silently degraded every stamped build to 000.
                with open(p, encoding="utf-8-sig") as f:
                    return json.load(f)
            except Exception:                      # a corrupt stamp must not stop startup
                continue
    return {}


_STAMP = _read_build_file()


def build_no():
    env = os.environ.get("DBDOME_BUILD_NO")
    if env and env.strip().isdigit():
        return int(env.strip())
    try:
        return int(_STAMP.get("build_no", 0))
    except (TypeError, ValueError):
        return 0


def built_by():
    return _STAMP.get("built_by") or ""


def notes():
    return _STAMP.get("notes") or ""


def version_string():
    """'2.01.043' - zero-padded, matching config.format_version()."""
    return f"{VERSION_MAJOR}.{VERSION_MINOR:02d}.{build_no():03d}"


def version_label():
    """'DBDOME v2.01.043' - for logs, the API and the page footer."""
    return f"DBDOME v{version_string()}"


def as_dict():
    return {
        "version": version_string(),
        "major": VERSION_MAJOR,
        "minor": VERSION_MINOR,
        "build_no": build_no(),
        "built_by": built_by(),
        "notes": notes(),
        "frozen": bool(getattr(sys, "frozen", False)),
    }


def register(component="service"):
    """Record the running version in config.app_version and mark it current.

    Best-effort: a version stamp is never worth failing startup over, so any DB
    problem is swallowed and reported by the return value."""
    try:
        import psycopg2

        from utils.config_dotenv import get_connection_string

        with psycopg2.connect(get_connection_string()) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT config.set_version(%s, %s, %s, %s, %s, %s)",
                    (VERSION_MAJOR, VERSION_MINOR, build_no(),
                     built_by() or None, notes() or None, component))
                return cur.fetchone()[0]
    except Exception as e:                          # noqa: BLE001 - startup must survive
        print(f"[version] could not register {version_string()}: {e}")
        return None


if __name__ == "__main__":
    # `python -m utils.version` prints the version - used by build.ps1 and by
    # anyone asking "what is this checkout going to build as?"
    print(version_string())
