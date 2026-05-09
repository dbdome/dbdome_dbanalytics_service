-- =============================================================================
-- ALTER script: dbanalytics_repo -> dbanalytics
-- Generated: 2026-04-12 05:29:05
-- Differences found: 52
-- =============================================================================
-- REVIEW THIS SCRIPT BEFORE RUNNING!
-- Lines starting with '-- REVIEW:' require manual decision.
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS flowchart.visual_objects_old (
    row_id integer NOT NULL DEFAULT nextval('flowchart.visual_objects_row_id_seq_'::regclass),
    source_object text NOT NULL,
    target_object text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    entry_date timestamp without time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS monitoring.general_metric_metadata_results_expensive_transactions (
    row_id integer,
    server varchar(50),
    category_id integer,
    metric_name varchar(255),
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone
);

CREATE TABLE IF NOT EXISTS monitoring.general_metric_metadata_results_transactions (
    row_id integer,
    server varchar(50),
    category_id integer,
    metric_name varchar(255),
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone
);

ALTER TABLE flowchart.visual_objects ADD COLUMN IF NOT EXISTS report_url text;

ALTER TABLE config.mail_config ALTER COLUMN smtp_password DROP NOT NULL;

ALTER TABLE monitoring.v_database_restored ALTER COLUMN backup_finish_date TYPE timestamp with time zone;

ALTER TABLE monitoring.v_database_restored ALTER COLUMN backup_start_date TYPE timestamp with time zone;

ALTER TABLE monitoring.v_database_restored ALTER COLUMN restore_date TYPE timestamp with time zone;

-- REVIEW: ALTER TABLE flowchart.visual_objects DROP COLUMN alert_mail;  -- exists in target but not source

-- REVIEW: ALTER TABLE flowchart.visual_objects DROP COLUMN alert_report;  -- exists in target but not source

-- REVIEW: ALTER TABLE flowchart.visual_objects DROP COLUMN alert_siem;  -- exists in target but not source

-- REVIEW: ALTER TABLE flowchart.visual_objects DROP COLUMN diagnosys;  -- exists in target but not source

-- REVIEW: ALTER TABLE flowchart.visual_objects DROP COLUMN metric_name;  -- exists in target but not source

-- REVIEW: ALTER TABLE metrics.servers DROP COLUMN server_id;  -- exists in target but not source

-- REVIEW: ALTER TABLE monitoring.general_metric_metadata_results DROP COLUMN metric_metadata_vs_expected;  -- exists in target but not source

-- REVIEW: ALTER TABLE monitoring.schema DROP COLUMN is_enabled;  -- exists in target but not source

-- REVIEW: ALTER TABLE rootcause.areas DROP COLUMN category_id;  -- exists in target but not source

-- REVIEW: ALTER TABLE rootcause.domains DROP COLUMN category_id;  -- exists in target but not source

-- REVIEW: ALTER TABLE rootcause.issues DROP COLUMN category_id;  -- exists in target but not source

CREATE INDEX ix_login_name ON monitoring.active_transactions USING btree (login_name);

CREATE INDEX cix_client_net_address ON monitoring.tcp_connections USING btree (client_net_address);

CREATE OR REPLACE VIEW monitoring.v_audit AS
 SELECT server,
    session_id,
    blocking_session_id,
    duration_secs,
    database_name,
    start_time,
    last_request_end_time,
    cpu_time,
    command,
    logical_reads,
    reads,
    writes,
    wait_type,
    last_wait_type,
    login_name,
    program_name,
    host_name,
    query
   FROM monitoring.active_transactions
  WHERE (((login_name)::text <> 'dbdome_mon_usr'::text) AND (lower(query) ~~ '%alter%'::text) AND (lower(query) !~~ '%alter event session%'::text))
  ORDER BY last_request_end_time DESC;;

CREATE OR REPLACE VIEW monitoring.v_sensitive_data_inuse AS
 SELECT at.server,
    at.login_name,
    at.query,
    (at.last_request_end_time AT TIME ZONE 'Asia/Jerusalem'::text) AS last_request_end_time,
    c.column_name,
    c.table_name
   FROM (monitoring.active_transactions at
     JOIN ( SELECT schema.table_name,
            schema.column_name
           FROM monitoring.schema
        UNION ALL
         SELECT sensitive_schema.table_name,
            sensitive_schema.column_name
           FROM monitoring.sensitive_schema) c ON ((at.query ~~ (('%'::text || (c.column_name)::text) || '%'::text))))
  WHERE ((at.login_name)::text ~~ '%\\%'::text);;

CREATE OR REPLACE VIEW monitoring.v_sensitive_schema AS
 SELECT server,
    data_type,
    table_name,
    column_name,
    table_catalog,
    entry_date
   FROM ( SELECT r.server,
            (j.value ->> 'DATA_TYPE'::text) AS data_type,
            (j.value ->> 'TABLE_NAME'::text) AS table_name,
            (j.value ->> 'COLUMN_NAME'::text) AS column_name,
            (j.value ->> 'TABLE_CATALOG'::text) AS table_catalog,
            (r.entry_date AT TIME ZONE 'Asia/Jerusalem'::text) AS entry_date
           FROM (monitoring.general_metric_metadata_results r
             CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
          WHERE (((r.metric_name)::text = 'sensitive_schema'::text) AND (r.server IS NOT NULL) AND (r.metric_metadata <> '[]'::jsonb))) unnamed_subquery
  WHERE (lower(column_name) ~~* ANY (ARRAY['%phone%'::text, '%id_num%'::text, '%tz%'::text, '%mail%'::text, '%address%'::text, '%heshbon%'::text, '%account%'::text, '%zip%'::text, '%bank%'::text, '%שם%'::text, '%position%'::text, '%fee%'::text, '%permission%'::text, '%currency%'::text, '%סכום%'::text, '%total%'::text, '%balance%'::text, '%sale%'::text, '%בנק%'::text, '%חשבון%'::text]));;

CREATE OR REPLACE VIEW monitoring.v_sql_injection AS
 SELECT vat.query_id,
    vat.server,
    vat.query,
    vat.reads,
    vat.writes,
    vat.command,
    vat.command_type,
    vat.cpu_time,
    vat.host_name,
    vat.wait_type,
    vat.login_name,
    vat.session_id,
    vat.start_time,
    vat.program_name,
    vat.database_name,
    vat.duration_secs,
    vat.logical_reads,
    vat.last_wait_type,
    vat.blocking_session_id,
    vat.last_request_end_time,
    vat.observed_at,
    vat.columns,
    vat.tables,
    vat.literal,
    vat.condition,
    vat.joins,
    vat.func,
    vat.anomaly_score
   FROM (monitoring.v_active_transactions vat
     JOIN metrics.sql_injection_patterns sip ON ((vat.query ~~ (('%'::text || (sip.pattern_clause)::text) || '%'::text))))
  WHERE ((vat.login_name)::text <> 'dbdome_mon_usr'::text)
UNION ALL
 SELECT vat.query_id,
    vat.server,
    vat.query,
    vat.reads,
    vat.writes,
    vat.command,
    vat.command_type,
    vat.cpu_time,
    vat.host_name,
    vat.wait_type,
    vat.login_name,
    vat.session_id,
    vat.start_time,
    vat.program_name,
    vat.database_name,
    vat.duration_secs,
    vat.logical_reads,
    vat.last_wait_type,
    vat.blocking_session_id,
    vat.last_request_end_time,
    vat.observed_at,
    vat.columns,
    vat.tables,
    vat.literal,
    vat.condition,
    vat.joins,
    vat.func,
    vat.anomaly_score
   FROM monitoring.v_active_transactions vat
  WHERE ((vat.query !~~ '%@%'::text) AND ((vat.login_name)::text <> 'dbdome_mon_usr'::text));;

CREATE OR REPLACE VIEW flowchart.v_sources_alerts AS
 SELECT o.row_id AS id,
    o.source_object AS source,
    o.target_object AS target,
    o.source_object AS title,
    ( SELECT flowchart.execute_numeric_query(o.mainstat_query) AS execute_numeric_query) AS mainstat,
    now() AS last_seen,
    ( SELECT flowchart.color_by_threshold(o.mainstat_query, o.mainstat_threshold_id) AS color_by_threshold) AS color,
    COALESCE(o.report_url, 'ad7kkx7/alerts'::text) AS report_url
   FROM flowchart.visual_objects o
UNION ALL
 SELECT servers.row_id AS id,
    servers.db_vendor AS source,
    servers.servername AS target,
    servers.servername AS title,
        CASE servers.is_active
            WHEN true THEN 1
            ELSE 0
        END AS mainstat,
    now() AS last_seen,
        CASE
            WHEN (servers.is_active IS TRUE) THEN 'green'::text
            ELSE 'red'::text
        END AS color,
    'ad7kkx7/alerts'::text AS report_url
   FROM metrics.servers
UNION ALL
 SELECT servers.row_id AS id,
    servers.servername AS source,
    'Data sources'::text AS target,
    'Data sources'::text AS title,
        CASE servers.is_active
            WHEN true THEN 1
            ELSE 0
        END AS mainstat,
    now() AS last_seen,
        CASE
            WHEN (servers.is_active IS TRUE) THEN 'green'::text
            ELSE 'red'::text
        END AS color,
    'ad7kkx7/alerts'::text AS report_url
   FROM metrics.servers;;

CREATE OR REPLACE VIEW monitoring.v_active_transactions AS
 WITH agg AS (
         SELECT row_number() OVER (PARTITION BY gmmr.server, gmmr.query ORDER BY gmmr.duration_secs DESC) AS seq,
            gmmr.row_id AS query_id,
            gmmr.server,
            gmmr.query,
            gmmr.reads,
            gmmr.writes,
                CASE
                    WHEN ((gmmr.command)::text = 'INSERT'::text) THEN 1
                    WHEN ((gmmr.command)::text = 'UPDATE'::text) THEN 2
                    WHEN ((gmmr.command)::text = 'DELETE'::text) THEN 3
                    WHEN ((gmmr.command)::text = 'EXECUTE'::text) THEN 2
                    ELSE 0
                END AS command_type,
            gmmr.command,
            gmmr.cpu_time,
            gmmr.host_name,
            gmmr.wait_type,
            gmmr.login_name,
            gmmr.session_id,
            gmmr.start_time,
            gmmr.program_name,
            gmmr.database_name,
            gmmr.duration_secs,
            gmmr.logical_reads,
            gmmr.last_wait_type,
            gmmr.blocking_session_id,
            gmmr.last_request_end_time,
            mqp.observed_at,
            mqp.columns,
            mqp.tables,
            mqp.literal,
            mqp.condition,
            mqp.joins,
            mqp.func,
            sa.anomaly_score
           FROM ((monitoring.active_transactions gmmr
             LEFT JOIN monitoring.metric_query_parsing mqp ON ((mqp.query_id = gmmr.row_id)))
             LEFT JOIN monitoring.autoencoder_sql_anomalies sa ON (((sa.query = gmmr.query) AND (sa.server = (gmmr.server)::text))))
          WHERE (gmmr.last_request_end_time >= (now() - '00:01:00'::interval))
        )
 SELECT query_id,
    server,
    query,
    reads,
    writes,
    command,
    command_type,
    cpu_time,
    host_name,
    wait_type,
    login_name,
    session_id,
    start_time,
    program_name,
    database_name,
    duration_secs,
    logical_reads,
    last_wait_type,
    blocking_session_id,
    last_request_end_time,
    observed_at,
    columns,
    tables,
    literal,
    condition,
    joins,
    func,
    NULLIF(anomaly_score, (0)::double precision) AS anomaly_score
   FROM agg
  WHERE ((seq = 1) AND ((login_name)::text <> ALL (ARRAY[('dbdome_mon_usr'::character varying)::text, ('NT AUTHORITY\ANONYMOUS LOGON'::character varying)::text])))
  ORDER BY NULLIF(anomaly_score, (0)::double precision) DESC;;

CREATE OR REPLACE VIEW monitoring.v_blocking_transactions AS
 SELECT r.server,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'total_elapsed_time'::text) AS total_elapsed_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'long_block_transactions'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results.entry_date) AS max
           FROM monitoring.general_metric_metadata_results
          WHERE ((general_metric_metadata_results.metric_name)::text = 'long_block_transactions'::text))));;

CREATE OR REPLACE VIEW monitoring.v_database_restored AS
 SELECT r.row_id,
    r.server,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'backup_file'::text) AS backup_file,
    to_timestamp(((((j.value ->> 'restore_date'::text))::bigint / 1000))::double precision) AS restore_date,
    to_timestamp(((((j.value ->> 'backup_start_date'::text))::bigint / 1000))::double precision) AS backup_start_date,
    to_timestamp(((((j.value ->> 'backup_finish_date'::text))::bigint / 1000))::double precision) AS backup_finish_date,
    (j.value ->> 'source_database_name'::text) AS source_database_name,
    (j.value ->> 'destination_database_name'::text) AS destination_database_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Database restored'::text) AND (r.server IS NOT NULL) AND (r.metric_metadata <> '[]'::jsonb));;

CREATE OR REPLACE VIEW monitoring.v_job_scheduler AS
 SELECT report_id,
    job_id,
    next_run,
    last_run,
    report_name,
    report_query,
    occurance,
    occurs_at,
    schedule_type,
    recipients,
    smtp_password,
    smtp_port,
    smtp_server,
    smtp_user,
    tls,
    mail_sender,
    alert_id,
    alert_name,
    alert_query,
    value_start,
    value_end
   FROM ( SELECT r.report_id,
            r.alert_id,
            r.alert_name,
            r.alert_query,
            j.row_id AS job_id,
            r.report_name,
            r.report_query,
            j.occurance,
            j.occurs_at,
            j.schedule_type,
            mg.recipients,
            mc.smtp_password,
            mc.smtp_port,
            mc.smtp_server,
            mc.smtp_user,
            mc.tls,
            mc.mail_sender,
            js.next_run,
            js.last_run,
            r.value_start,
            r.value_end
           FROM ((((((( SELECT r_1.row_id AS report_id,
                    r_1.report_name,
                    r_1.report_query,
                    a_1.row_id AS alert_id,
                    a_1.alert_name,
                    a_1.alert_query,
                    a_1.value_start,
                    a_1.value_end
                   FROM ((config.reports r_1
                     LEFT JOIN config.alerts_reports ar ON ((ar.report_id = r_1.row_id)))
                     LEFT JOIN ( SELECT a_2.row_id,
                            a_2.alert_name,
                            a_2.alert_query,
                            a_2.entry_date,
                            t.value_start,
                            t.value_end
                           FROM ((config.alerts a_2
                             JOIN config.alerts_thresholds ta ON ((ta.alert_id = a_2.row_id)))
                             JOIN config.thresholds t ON ((t.row_id = ta.threshold_id)))) a_1 ON ((a_1.row_id = ar.alert_id)))) r
             JOIN config.reports_jobs rj ON ((rj.report_id = r.report_id)))
             JOIN jobs.jobs j ON ((j.row_id = rj.job_id)))
             JOIN config.mail_jobs mj ON ((mj.job_id = rj.job_id)))
             JOIN config.mail_config mc ON ((mc.row_id = mj.mail_id)))
             JOIN config.mail_groups mg ON ((mg.mail_config_id = mc.row_id)))
             LEFT JOIN jobs.job_schedules js ON (((js.report_id = r.report_id) AND (js.schedule_id = j.row_id))))) a
  WHERE ((COALESCE((next_run)::timestamp with time zone, now()) <= now()) AND (last_run IS NULL));;

CREATE OR REPLACE VIEW rootcause.v_root_cause_alerts AS
 SELECT DISTINCT raqrs.server,
    rc.domain_name,
    rc.area_name,
    rc.issue_name,
    rc.root_cause_id,
    rc.root_cause_name,
    rc.root_cause_desc,
    rc.detection_name,
    rc.detection_desc,
    rc.step_name,
    raqrs.query_result AS execute_numeric_query,
    rc.risk_level
   FROM (((rootcause.v_rootcauses rc
     JOIN rootcause.rootcause_alert_query raq ON ((raq.root_cause_id = (rc.root_cause_id)::text)))
     JOIN rootcause.rootcause_alert_query_result_server raqrs ON ((raqrs.root_cause_id = (rc.root_cause_id)::text)))
     JOIN metrics.servers s ON ((s.server = raqrs.server)))
  WHERE ((lower((rc.vendor_name)::text) = lower(s.db_vendor)) OR (lower((rc.vendor_name)::text) = 'sqlserver'::text));;

-- Changed: dbms_profiler.stop_profiler()
CREATE OR REPLACE FUNCTION dbms_profiler.stop_profiler()
 RETURNS integer
 LANGUAGE edbspl
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
$__EDBwrapped__$$PROTOCOL2$
UTF8
dwEfRZrz8tXcQFQnspytzij3Cw75YW2IhMsvz6jRvd4HbSsSlr95jArRCKhZWZYcTA+bMBMeGAgB
amcQtcVqvMSbXK+Yrukfu+ZnM8jMRRzDxYWVG/NqzJBYpz3lITIA+gVJDs01qXvZ0QW6CVxQrPWo
Je/4dhlwf22XAj8z+90zSaKRZMQ1s8zbwYp1WvCwG72nAOGMKoAnaOOdGmkez8O2/lYQ68JEzyge
RxQ1E4r/kKHUpkvyXwYKj91pVbcXoZU2di9M3KM0dkPL6LVUC5CXEt1wAj+zDId/5vQo0nu/Jvf6
MCWBoU07F04bFlNOu7ITAW2GZHdxziHnAaCfkWPoXm3etYjKsM6iCwLm+HnEEKvt+wF+xFxc0e0r
dFPuQ+HNYQQDBzOWKi1b
$__EDBwrapped__$$function$
;

-- Changed: flowchart.execute_numeric_query(p_sql text)
CREATE OR REPLACE FUNCTION flowchart.execute_numeric_query(p_sql text)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    result numeric := 0;
BEGIN
    IF p_sql IS NOT NULL THEN
        EXECUTE p_sql INTO result;
    END IF;

    RETURN COALESCE(result, 0);
END;
$function$
;

-- Changed: maintenance.changerandomaldates()
CREATE OR REPLACE PROCEDURE maintenance.changerandomaldates()
 SECURITY INVOKER
AS $procedure$
BEGIN
    UPDATE monitoring.active_transactions
    SET 
        last_request_end_time =
            date_trunc('day', now()) +
            make_interval(
                hours => floor(random() * 24)::int,
                mins  => floor(random() * 60)::int,
                secs  => floor(random() * 60)::int
            ),
        start_time =
            date_trunc('day', now()) +
            make_interval(
                hours => floor(random() * 24)::int,
                mins  => floor(random() * 60)::int,
                secs  => floor(random() * 60)::int
            );
    UPDATE monitoring.general_metric_metadata_results
    SET 
        entry_date =
            date_trunc('day', now()) +
            make_interval(
                hours => floor(random() * 24)::int,
                mins  => floor(random() * 60)::int,
                secs  => floor(random() * 60)::int
            );

END;
$procedure$
 LANGUAGE plpgsql
;

-- Changed: metrics.upsert_monitored_server(IN p_ip_address text, IN p_server_name text, IN p_db_vendor text, IN p_db_version text, IN p_auth_type text, IN p_username text, IN p_password text, IN p_add_modify_delete text)
CREATE OR REPLACE PROCEDURE metrics.upsert_monitored_server(IN p_ip_address text, IN p_server_name text, IN p_db_vendor text, IN p_db_version text, IN p_auth_type text, IN p_username text, IN p_password text, IN p_add_modify_delete text)
 SECURITY INVOKER
AS $procedure$
DECLARE
    v_new_id INT;
BEGIN
    IF p_add_modify_delete != 'delete' AND NOT EXISTS (
        SELECT 1 FROM metrics.servers WHERE servername = p_server_name
    ) THEN
    
        -- Insert into metrics.servers and capture the new row_id
        INSERT INTO metrics.servers (
            server, servername, db_vendor, db_version, auth_type, username, password , driver 
        )
        VALUES (
            p_ip_address, p_server_name, p_db_vendor, p_db_version,
            p_auth_type, p_username, p_password,'ODBC+Driver+17+for+SQL+Server'
        )
        RETURNING row_id INTO v_new_id;
        
        -- Insert into metrics.server_routines (example) using the captured ID
        INSERT INTO metrics.servers_routines (server_id, routine_id, scheduler_id)
        SELECT v_new_id, row_id, 1
        FROM metrics.routines
        WHERE db_version = p_db_version;
    	insert into config.retention_policy (server , table_name)
		select p_ip_address , table_schema || '.'|| table_name from information_schema.tables;
		insert into config.action_types( server  , action_name  , action_description  , is_active) 
		select server  , action_name  , action_description  , is_active  from config.action_types
		where server = 'unknown';

    ELSE
        -- Delete if exists and requested
        DELETE FROM metrics.servers WHERE servername = p_server_name;
    END IF;
END;
$procedure$
 LANGUAGE plpgsql
;

-- Changed: metrics.upsert_monitored_server(IN p_ip_address text, IN p_server_name text, IN p_db_vendor text, IN p_db_version text, IN p_auth_type text, IN p_username text, IN p_password text, IN p_service_name text, IN p_add_modify_delete text)
CREATE OR REPLACE PROCEDURE metrics.upsert_monitored_server(IN p_ip_address text, IN p_server_name text, IN p_db_vendor text, IN p_db_version text, IN p_auth_type text, IN p_username text, IN p_password text, IN p_service_name text, IN p_add_modify_delete text)
 SECURITY INVOKER
AS $procedure$
DECLARE
    v_new_id INT;
BEGIN
    IF p_add_modify_delete != 'delete' AND NOT EXISTS (
        SELECT 1 FROM metrics.servers WHERE servername = p_server_name
    ) THEN
    
        -- Insert into metrics.servers and capture the new row_id
        INSERT INTO metrics.servers (
            server, servername, db_vendor, db_version, auth_type, username, password , service_name , driver
        )
        VALUES (
            p_ip_address, p_server_name, p_db_vendor, p_db_version,
            p_auth_type, p_username, p_password , p_service_name , 'ODBC+Driver+17+for+SQL+Server'
        )
        RETURNING row_id INTO v_new_id;
        
        -- Insert into metrics.server_routines (example) using the captured ID
        INSERT INTO metrics.servers_routines (server_id, routine_id, scheduler_id)
        SELECT v_new_id, row_id, 1
        FROM metrics.routines
        WHERE db_version = p_db_version;
    	insert into config.retention_policy (server , table_name)
		select p_ip_address , table_schema || '.'|| table_name from information_schema.tables;
		insert into config.action_types( server  , action_name  , action_description  , is_active) 
		select server  , action_name  , action_description  , is_active  from config.action_types
		where server = 'unknown';

    ELSE
        -- Delete if exists and requested
        DELETE FROM metrics.servers WHERE servername = p_server_name;
    END IF;
END;
$procedure$
 LANGUAGE plpgsql
;



-- Uncomment to apply:
-- COMMIT;

-- To rollback:
-- ROLLBACK;
