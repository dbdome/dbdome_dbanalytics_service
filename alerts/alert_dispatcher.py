"""
Background alert dispatcher.

Alert deliveries (SMTP email, SIEM/webhook HTTP) are slow and can block on an
unreachable endpoint. Running them inline in the collection loop made a single
slow mail server freeze metric collection for minutes (backends stuck
"idle in transaction"). This module moves delivery OFF the collection thread:

    dispatch(send_fn, *args, **kwargs)   # fire-and-forget, never blocks

The collector enqueues a delivery callable and immediately moves on; one daemon
worker drains the queue serially in the background. If the queue backs up
(deliveries failing/slow), new alerts are dropped-with-a-log rather than ever
blocking the collector.
"""
import queue
import threading

from utils.log4dbexpert import db_write_log

# Cap the backlog so a permanently-down endpoint can't grow memory unbounded.
_MAXSIZE = 5000
_q = queue.Queue(maxsize=_MAXSIZE)
_worker = None
_lock = threading.Lock()


def _worker_loop():
    while True:
        fn, args, kwargs, label = _q.get()
        try:
            fn(*args, **kwargs)
        except Exception as e:
            try:
                db_write_log(f"alert dispatch '{label}' failed: {e}", 0, "alert_dispatcher", "")
            except Exception:
                pass
        finally:
            _q.task_done()


def _ensure_worker():
    global _worker
    if _worker is not None and _worker.is_alive():
        return
    with _lock:
        if _worker is None or not _worker.is_alive():
            _worker = threading.Thread(
                target=_worker_loop, name="alert-dispatcher", daemon=True
            )
            _worker.start()


def dispatch(fn, *args, label="alert", **kwargs):
    """Enqueue an alert-delivery callable to run in the background.

    Never blocks the caller. If the queue is full (deliveries backed up behind a
    slow endpoint), the alert is dropped and logged rather than stalling
    collection — collection integrity matters more than a single alert.
    """
    _ensure_worker()
    try:
        _q.put_nowait((fn, args, kwargs, label))
    except queue.Full:
        try:
            db_write_log(f"alert queue full ({_MAXSIZE}) — dropped '{label}'", 0, "alert_dispatcher", "")
        except Exception:
            pass


def pending() -> int:
    """Approximate number of queued (not-yet-delivered) alerts — for diagnostics."""
    return _q.qsize()
