"""Windows Service wrapper for DBDOME dbanalytics.

Requires: pip install pywin32

Usage:
    python dbdome_service.py install     # Install the service
    python dbdome_service.py start       # Start the service
    python dbdome_service.py stop        # Stop the service
    python dbdome_service.py restart     # Restart the service
    python dbdome_service.py remove      # Uninstall the service
    python dbdome_service.py debug       # Run in debug/console mode

Or via sc.exe / services.msc after install.
"""

import os
import sys
import time
import subprocess
import traceback
import threading

import win32serviceutil
import win32service
import win32event
import servicemanager

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None


def _service_dir():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def _open_service_log():
    """Redirect stdout/stderr to a rolling log file next to the exe.

    Services have no console. Many libraries (uvicorn, APScheduler) crash on first
    write if sys.stdout is None or lacks a fileno(). Point them at a real file.
    """
    log_path = os.path.join(_service_dir(), "dbdome_service.log")
    try:
        # line-buffered so we can tail it live
        f = open(log_path, "a", buffering=1, encoding="utf-8", errors="replace")
        sys.stdout = f
        sys.stderr = f
        return log_path
    except Exception:
        return None


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


class DBDOMEService(win32serviceutil.ServiceFramework):
    _svc_name_ = "DBDOME_dbanalytics"
    _svc_display_name_ = "DBDOME dbanalytics Service"
    _svc_description_ = "DBDOME database monitoring - scheduler + HTTP server"

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.scheduler = None
        self.running = True
        self.init_thread = None
        self.init_ok = False
        self.grafana_thread = None

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING, waitHint=10000)
        _log("SvcStop received")
        self.running = False
        if self.scheduler:
            try:
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
            _log("init_worker: calling run(port=8080)")
            self.scheduler = run(port=8080)
            self.init_ok = True
            _log("init_worker: run() returned — service fully initialized")
        except Exception as e:
            _log_error(f"init_worker crashed: {e}")
            _log_error(traceback.format_exc())
            # Trip the stop event so SvcDoRun exits and SCM marks service stopped
            self.running = False
            try:
                win32event.SetEvent(self.stop_event)
            except Exception:
                pass

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

        # 4a. Start the grafana watchdog (no-op if GRAFANA_EXE not set)
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


if __name__ == "__main__":
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(DBDOMEService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(DBDOMEService)
