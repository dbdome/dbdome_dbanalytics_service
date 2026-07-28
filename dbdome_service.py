"""Windows Service wrapper for DBDOME dbanalytics.

Requires: pip install pywin32

Usage:
    python dbdome_service.py [--service full|scheduler|web] <command>

Commands: install, start, stop, restart, remove, debug

Examples:
    python dbdome_service.py install                      # full (scheduler + HTTP)
    python dbdome_service.py --service scheduler install  # scheduler only
    python dbdome_service.py --service web install        # HTTP server only
    python dbdome_service.py --service web start

Or via sc.exe / services.msc after install.
"""

import warnings
# Silence pandas' cosmetic UserWarning about raw DBAPI2 connections in read_sql.
warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy connectable")

import os
import sys
import time
import subprocess
import traceback
import threading

# Force matplotlib's non-interactive backend before anything imports pyplot.
# On Windows (session-0 service) the default GUI backend (Tk) has no display and
# blocks forever when a report renders a chart — this made the IPS report hang.
os.environ.setdefault("MPLBACKEND", "Agg")

import win32serviceutil
import win32service
import win32event
import servicemanager

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None

# Initialise Oracle thick mode at process entry point — must run before any
# other import that calls oracledb.connect(), or thin mode locks in for the
# lifetime of the process.
try:
    from utils.oracle_client import oracle_connect as _  # noqa: F401
except Exception:
    pass  # oracledb not installed on this machine


def _service_dir():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


_log_fh = None   # module-level so the hourly rotation thread can reach it


def _open_service_log():
    """Redirect stdout/stderr to a log file next to the exe.

    Services have no console. Many libraries (uvicorn, APScheduler) crash on first
    write if sys.stdout is None or lacks a fileno(). Point them at a real file.
    """
    global _log_fh
    log_path = os.path.join(_service_dir(), "dbdome_service.log")
    try:
        # line-buffered so we can tail it live
        f = open(log_path, "w", buffering=1, encoding="utf-8", errors="replace")
        sys.stdout = f
        sys.stderr = f
        _log_fh = f
        return log_path
    except Exception:
        return None


def _log_rotate_worker(stop_event):
    """Truncate dbdome_service.log to zero bytes once per hour."""
    while True:
        rc = win32event.WaitForSingleObject(stop_event, 3600 * 1000)
        if rc == win32event.WAIT_OBJECT_0:
            break
        try:
            if _log_fh is not None:
                _log_fh.seek(0)
                _log_fh.truncate(0)
                _log_fh.flush()
        except Exception:
            pass


def _log(msg):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{stamp}] {msg}"
    try:
        print(line, flush=True)
    except Exception:
        pass
    try:
        servicemanager.LogInfoMsg(line)
    except Exception:
        pass
    try:
        from utils.log4dbexpert import db_write_log
        db_write_log(str(msg), "INFO", "service", "")
    except Exception:
        pass


def _grafana_is_running():
    """Return True if grafana.exe is present in tasklist."""
    try:
        out = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq grafana.exe", "/NH"],
            capture_output=True, text=True, timeout=10,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        return "grafana.exe" in (out.stdout or "").lower()
    except Exception:
        return False


def _log_error(msg):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{stamp}] ERROR: {msg}"
    try:
        print(line, flush=True)
    except Exception:
        pass
    try:
        servicemanager.LogErrorMsg(line)
    except Exception:
        pass
    try:
        from utils.log4dbexpert import db_write_log
        db_write_log(str(msg), "ERROR", "service", "")
    except Exception:
        pass


class DBDOMEServiceBase(win32serviceutil.ServiceFramework):
    """Base class for all DBDOME service variants.

    Subclasses set _run_kwargs_ to control what run() receives.
    """
    _svc_name_ = "DBDOME_dbanalytics"
    _svc_display_name_ = "DBDOME dbanalytics Service"
    _svc_description_ = "DBDOME database monitoring"
    _run_kwargs_ = {"port": 8080}

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.scheduler = None
        self.running = True
        self.init_thread = None
        self.init_ok = False
        self.grafana_thread = None
        self.rotate_thread = None

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING, waitHint=10000)
        _log("SvcStop received")
        self.running = False
        if self.scheduler:
            try:
                # Pause first so the scheduler's timer stops submitting jobs to the
                # executor before we shut it down — avoids the
                # "cannot schedule new futures after shutdown" RuntimeError.
                self.scheduler.pause()
                self.scheduler.shutdown(wait=False)
            except Exception as e:
                _log_error(f"scheduler.shutdown failed: {e}")
        win32event.SetEvent(self.stop_event)

    def _grafana_watchdog(self):
        """Every GRAFANA_WATCHDOG_INTERVAL seconds, ensure grafana.exe is running."""
        grafana_exe = (os.getenv("GRAFANA_EXE") or "").strip().strip('"')
        try:
            interval = int(os.getenv("GRAFANA_WATCHDOG_INTERVAL", "60") or 60)
        except ValueError:
            interval = 60

        if not grafana_exe:
            _log("grafana watchdog disabled (GRAFANA_EXE not set)")
            return
        if not os.path.exists(grafana_exe):
            _log_error(f"grafana watchdog disabled — exe not found: {grafana_exe}")
            return

        _log(f"grafana watchdog: starting (exe={grafana_exe}, interval={interval}s)")
        last_running = None
        while self.running:
            try:
                running = _grafana_is_running()
                if running != last_running:
                    _log(f"grafana watchdog: grafana.exe {'running' if running else 'NOT running'}")
                    last_running = running
                if not running:
                    _log(f"grafana watchdog: launching {grafana_exe}")
                    subprocess.Popen(
                        [grafana_exe],
                        cwd=os.path.dirname(grafana_exe),
                        creationflags=(
                            getattr(subprocess, "CREATE_NO_WINDOW", 0)
                            | getattr(subprocess, "DETACHED_PROCESS", 0)
                        ),
                    )
            except Exception as e:
                _log_error(f"grafana watchdog tick failed: {e}")

            rc = win32event.WaitForSingleObject(self.stop_event, interval * 1000)
            if rc == win32event.WAIT_OBJECT_0:
                break

        _log("grafana watchdog: exited")

    def _init_worker(self):
        """Heavy initialization — runs in background thread so SCM isn't waiting."""
        try:
            _log("init_worker: importing dbdome_main")
            from dbdome_main import run
            kwargs = self.__class__._run_kwargs_
            _log(f"init_worker: calling run({', '.join(f'{k}={v}' for k, v in kwargs.items())})")
            self.scheduler = run(**kwargs)
            self.init_ok = True
            _log("init_worker: run() returned — service fully initialized")
        except Exception as e:
            _log_error(f"init_worker crashed: {e}")
            _log_error(traceback.format_exc())
            # Do NOT tear the whole service down on an init error — that turned a
            # transient/partial failure into an SCM crash-loop. Stay up (degraded):
            # the scheduler may have partially started, SvcStop still works, and the
            # failure is logged for diagnosis instead of bouncing the process.
            self.init_ok = False

    def SvcDoRun(self):
        # 1. Redirect stdout/stderr BEFORE any other imports/prints can fail
        log_path = _open_service_log()

        # 2. Report START_PENDING with a generous wait hint (SCM will be patient)
        self.ReportServiceStatus(win32service.SERVICE_START_PENDING, waitHint=60000)

        _log("=" * 60)
        _log("SvcDoRun starting")
        _log(f"log file: {log_path}")
        _log(f"frozen: {getattr(sys, 'frozen', False)}")
        _log(f"executable: {sys.executable}")

        # 3. chdir + sys.path so dbdome_main imports resolve
        try:
            sd = _service_dir()
            os.chdir(sd)
            sys.path.insert(0, sd)
            _log(f"cwd: {sd}")
        except Exception as e:
            _log_error(f"chdir/sys.path failed: {e}")
            self.ReportServiceStatus(win32service.SERVICE_STOPPED)
            return

        # 3a. Load .env so watchdog and other components see configured vars
        if load_dotenv is not None:
            try:
                env_path = os.path.join(_service_dir(), ".env")
                load_dotenv(env_path)
                _log(f"loaded env: {env_path}")
            except Exception as e:
                _log_error(f"load_dotenv failed: {e}")

        # 4. Start heavy init in background; it can take as long as it needs
        self.init_thread = threading.Thread(
            target=self._init_worker, name="dbdome-init", daemon=True
        )
        self.init_thread.start()

        # 4b. Hourly log rotation — truncates dbdome_service.log to zero every hour
        self.rotate_thread = threading.Thread(
            target=_log_rotate_worker, args=(self.stop_event,),
            name="log-rotate", daemon=True
        )
        self.rotate_thread.start()

        # 4a. Start the grafana watchdog (web and full services only)
        if not self.__class__._run_kwargs_.get("scheduler_only"):
            self.grafana_thread = threading.Thread(
                target=self._grafana_watchdog, name="grafana-watchdog", daemon=True
            )
            self.grafana_thread.start()

        # 5. Report RUNNING immediately so SCM unblocks — we're "up"
        self.ReportServiceStatus(win32service.SERVICE_RUNNING)
        _log("reported SERVICE_RUNNING; waiting for stop event")

        # 6. Main wait loop — exits when SvcStop or init_worker trips stop_event
        while self.running:
            rc = win32event.WaitForSingleObject(self.stop_event, 5000)
            if rc == win32event.WAIT_OBJECT_0:
                break

        _log("SvcDoRun exiting (running=False)")
        self.ReportServiceStatus(win32service.SERVICE_STOPPED)


class DBDOMEService(DBDOMEServiceBase):
    """Combined service: scheduler + HTTP server."""
    _svc_name_ = "DBDOME_dbanalytics"
    _svc_display_name_ = "DBDOME dbanalytics Service"
    _svc_description_ = "DBDOME database monitoring - scheduler + HTTP server"
    _run_kwargs_ = {"port": 8080}


class DBDOMESchedulerService(DBDOMEServiceBase):
    """Scheduler-only service: runs metric collection jobs, no HTTP."""
    _svc_name_ = "DBDOME_scheduler"
    _svc_display_name_ = "DBDOME Scheduler Service"
    _svc_description_ = "DBDOME database monitoring - scheduler only"
    _run_kwargs_ = {"scheduler_only": True}


class DBDOMEWebService(DBDOMEServiceBase):
    """Web-only service: serves the HTTP/Grafana UI, no scheduler."""
    _svc_name_ = "DBDOME_web"
    _svc_display_name_ = "DBDOME Web Service"
    _svc_description_ = "DBDOME database monitoring - HTTP server only"
    _run_kwargs_ = {"web_only": True, "port": 8080}


_SERVICE_MAP = {
    "full":      DBDOMEService,
    "scheduler": DBDOMESchedulerService,
    "web":       DBDOMEWebService,
}


def _scm_install(svc_class, mode):
    """Register the service with the SCM with --service <mode> in the binary path.

    pywin32's HandleCommandLine install writes only sys.executable to the registry,
    so the SCM would always start the service in 'full' mode. We call
    win32service.CreateService directly to bake --service <mode> into ImagePath.
    """
    exe = os.path.abspath(sys.executable)
    bin_path = f'"{exe}" --service {mode}'

    scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_CREATE_SERVICE)
    try:
        handle = win32service.CreateService(
            scm,
            svc_class._svc_name_,
            svc_class._svc_display_name_,
            win32service.SERVICE_ALL_ACCESS,
            win32service.SERVICE_WIN32_OWN_PROCESS,
            win32service.SERVICE_AUTO_START,
            win32service.SERVICE_ERROR_NORMAL,
            bin_path,
            None, 0, None, None, None,
        )
        try:
            win32service.ChangeServiceConfig2(
                handle,
                win32service.SERVICE_CONFIG_DESCRIPTION,
                svc_class._svc_description_,
            )
        except Exception:
            pass
        win32service.CloseServiceHandle(handle)
        print(f"Installed: {svc_class._svc_name_} ({svc_class._svc_display_name_})")
        print(f"  ImagePath: {bin_path}")
    except win32service.error as e:
        if e.winerror == 1073:  # ERROR_SERVICE_EXISTS
            print(f"Service '{svc_class._svc_name_}' already exists. Run 'remove' first.")
        else:
            raise
    finally:
        win32service.CloseServiceHandle(scm)


def _scm_remove(svc_class):
    scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_ALL_ACCESS)
    try:
        handle = win32service.OpenService(scm, svc_class._svc_name_, win32service.SERVICE_ALL_ACCESS)
        try:
            win32service.DeleteService(handle)
            print(f"Removed: {svc_class._svc_name_}")
        finally:
            win32service.CloseServiceHandle(handle)
    except win32service.error as e:
        if e.winerror == 1060:  # ERROR_SERVICE_DOES_NOT_EXIST
            print(f"Service '{svc_class._svc_name_}' not found.")
        else:
            raise
    finally:
        win32service.CloseServiceHandle(scm)


if __name__ == "__main__":
    import argparse as _ap
    _p = _ap.ArgumentParser(add_help=False)
    _p.add_argument("--service", choices=_SERVICE_MAP.keys(), default="full")
    _known, _remaining = _p.parse_known_args()
    sys.argv = [sys.argv[0]] + _remaining

    svc_class = _SERVICE_MAP[_known.service]
    mode = _known.service

    # Intercept install/remove so the binary path includes --service <mode>.
    # All other commands (start, stop, restart, debug) go straight to pywin32.
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(svc_class)
        servicemanager.StartServiceCtrlDispatcher()
    elif sys.argv[1].lower() == "install":
        _scm_install(svc_class, mode)
    elif sys.argv[1].lower() == "remove":
        _scm_remove(svc_class)
    elif sys.argv[1].lower() == "start":
        win32serviceutil.StartService(svc_class._svc_name_)
        print(f"Service '{svc_class._svc_name_}' start signal sent.")
    elif sys.argv[1].lower() == "stop":
        win32serviceutil.StopService(svc_class._svc_name_)
        print(f"Service '{svc_class._svc_name_}' stop signal sent.")
    elif sys.argv[1].lower() == "restart":
        win32serviceutil.StopService(svc_class._svc_name_)
        time.sleep(2)
        win32serviceutil.StartService(svc_class._svc_name_)
        print(f"Service '{svc_class._svc_name_}' restarted.")
    elif sys.argv[1].lower() == "debug":
        print(f"Debug mode: {svc_class._svc_name_} — press Ctrl-C to stop.")
        svc = svc_class([svc_class._svc_name_])
        svc.SvcDoRun()
    else:
        print(f"Unknown command '{sys.argv[1]}'. Valid: install remove start stop restart debug")
        sys.exit(1)
