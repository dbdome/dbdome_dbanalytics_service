-- =============================================================================
-- 7670_mail_send_log.sql
--
-- alerts.mail_send_log - one row per attempt to send a mail alert or report,
-- including the ones that FAIL, plus the ones that are silently skipped.
--
-- WHY THIS EXISTS
--   "Did the alert mail go out?" had no answer. alerts.mail_alert_log records
--   only SUCCESSFUL alert sends (it is the 72-hour dedup ledger), so a failed
--   send left no row anywhere, and the code paths around it hid the reason:
--
--     * send_mail_alert_no_attachment logged failures with
--       db_write_log("...failed with error:{e}", 0, ...) - level 0, i.e. the
--       same severity as routine chatter, with no host, port, recipient,
--       subject or auth mode in the text. Finding one meant grepping
--       log.operation_log for a substring.
--     * When config.mail_config had no row, the `if row:` branch simply did
--       nothing - no send, no log line, no error. Same for "no recipients".
--     * Several senders (send_mail_with_pdf_attachment,
--       send_mail_with_html_attachment) swallow the exception entirely, and
--       three different functions logged under the SAME routine name
--       "send_mail_with_attachment", so a failure could not even be traced
--       back to which sender produced it.
--     * The SMTP cooldown (10 min after a failure) suppresses later alerts;
--       that suppression was invisible unless you knew to look for it.
--
--   This table makes every outcome explicit and queryable: attempted, sent,
--   failed (with the stage it failed at and the SMTP code), or skipped (with
--   the reason). It is a DIAGNOSTIC log, not a delivery ledger - the existing
--   alerts.mail_alert_log keeps its dedup role untouched.
--
-- STAGE
--   Where the attempt died, so a bad password is never confused with a blocked
--   port or a rejected recipient:
--     config     - nothing to send with (no mail_config row, no recipients)
--     attach     - the report file could not be read/attached
--     connect    - TCP connect / greeting / STARTTLS failed
--     auth       - the SMTP login was rejected (535, 534, AUTH unsupported)
--     send       - the server refused the message (550, 552, 554, timeout)
--     skipped    - deliberately not sent (cooldown, dedup, authorisation gate)
--
-- RETENTION
--   Trimmed to 90 days by the same retention engine that handles the other log
--   tables; nothing here is needed once an incident is understood.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS alerts;

CREATE TABLE IF NOT EXISTS alerts.mail_send_log (
    row_id        bigserial PRIMARY KEY,
    entry_date    timestamptz NOT NULL DEFAULT now(),
    -- what kind of mail this was: alert | report | test | internal | grc
    channel       text,
    -- the python function that attempted the send, so a failure is traceable
    -- to one sender even when several share a log message
    routine       text,
    -- sent | failed | skipped
    status        text NOT NULL,
    -- see STAGE above; NULL for a clean send
    stage         text,
    smtp_server   text,
    smtp_port     integer,
    tls           boolean,
    -- 'anonymous' when no SMTP user is configured, else 'user:<name>'. Never a
    -- password, and never the password's length.
    auth_mode     text,
    mail_sender   text,
    recipients    text,
    subject       text,
    attachments   text,
    -- monitored server / root cause the alert belongs to, when it is an alert
    server_name   text,
    root_cause_id text,
    duration_ms   numeric,
    error_class   text,
    error_code    text,
    error_text    text
);

CREATE INDEX IF NOT EXISTS ix_mail_send_log_entry_date
    ON alerts.mail_send_log (entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_mail_send_log_status
    ON alerts.mail_send_log (status, entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_mail_send_log_channel
    ON alerts.mail_send_log (channel, entry_date DESC);

COMMENT ON TABLE alerts.mail_send_log IS
    'Diagnostic log of every mail alert / report send attempt: sent, failed (with stage + SMTP code) or skipped (with reason). alerts.mail_alert_log remains the successful-alert dedup ledger.';

-- --------------------------------------------------------------------------
-- Views the operator actually opens
-- --------------------------------------------------------------------------

-- Everything that did NOT result in a delivered mail, newest first.
CREATE OR REPLACE VIEW alerts.v_mail_send_errors AS
SELECT row_id,
       entry_date,
       channel,
       status,
       stage,
       COALESCE(error_class, '')                        AS error_class,
       COALESCE(error_code, '')                         AS error_code,
       error_text,
       smtp_server || ':' || COALESCE(smtp_port::text, '?') AS smtp_target,
       tls,
       auth_mode,
       mail_sender,
       recipients,
       subject,
       server_name,
       root_cause_id,
       routine,
       duration_ms
FROM alerts.mail_send_log
WHERE status <> 'sent'
ORDER BY entry_date DESC;

COMMENT ON VIEW alerts.v_mail_send_errors IS
    'Mail sends that failed or were skipped, newest first - the first place to look when an alert or report did not arrive.';

-- Every attempt, delivered or not.
CREATE OR REPLACE VIEW alerts.v_mail_send_recent AS
SELECT row_id, entry_date, channel, status, stage,
       smtp_server || ':' || COALESCE(smtp_port::text, '?') AS smtp_target,
       auth_mode, recipients, subject, attachments,
       server_name, root_cause_id, routine, duration_ms,
       error_class, error_code, error_text
FROM alerts.mail_send_log
ORDER BY entry_date DESC;

-- Rolled up per day + outcome, for "is mail healthy?" at a glance.
CREATE OR REPLACE VIEW alerts.v_mail_send_summary AS
SELECT date_trunc('day', entry_date)          AS day,
       channel,
       status,
       stage,
       error_class,
       count(*)                                AS attempts,
       max(entry_date)                         AS last_seen,
       round(avg(duration_ms), 1)              AS avg_ms
FROM alerts.mail_send_log
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, attempts DESC;

-- --------------------------------------------------------------------------
-- Grants. The service connects as the monitoring user and must be able to
-- INSERT its own diagnostics; Grafana reads the views. Guarded so the script
-- is safe on an install where a role is absent.
-- --------------------------------------------------------------------------
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr') THEN
        GRANT USAGE ON SCHEMA alerts TO dbdome_mon_usr;
        GRANT SELECT, INSERT ON alerts.mail_send_log TO dbdome_mon_usr;
        GRANT USAGE, SELECT ON SEQUENCE alerts.mail_send_log_row_id_seq TO dbdome_mon_usr;
        GRANT SELECT ON alerts.v_mail_send_errors, alerts.v_mail_send_recent,
                        alerts.v_mail_send_summary TO dbdome_mon_usr;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        GRANT SELECT, INSERT ON alerts.mail_send_log TO dbdome_engine;
        GRANT USAGE, SELECT ON SEQUENCE alerts.mail_send_log_row_id_seq TO dbdome_engine;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        GRANT SELECT ON alerts.mail_send_log TO dbdome_grafana_ro;
        GRANT SELECT ON alerts.v_mail_send_errors, alerts.v_mail_send_recent,
                        alerts.v_mail_send_summary TO dbdome_grafana_ro;
    END IF;
END
$do$;
