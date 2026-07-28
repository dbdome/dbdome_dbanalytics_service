-- Idempotent install for widget.report_items_indicators
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.report_items_indicators_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.report_items_indicators (
    row_id integer NOT NULL,
    report_item_id integer NOT NULL,
    label character varying(255) NOT NULL,
    risk integer NOT NULL,
    icon character varying(50) NOT NULL,
    goto character varying(50) NOT NULL,
    detailfiles text,
    query text,
    kpi integer,
    threshold_critical integer NOT NULL
);

ALTER TABLE widget.report_items_indicators ALTER COLUMN row_id SET DEFAULT nextval('widget.report_items_indicators_row_id_seq'::regclass);
ALTER SEQUENCE widget.report_items_indicators_row_id_seq OWNED BY widget.report_items_indicators.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.report_items_indicators);
COPY _stg_load (row_id, report_item_id, label, risk, icon, goto, detailfiles, query, kpi, threshold_critical) FROM stdin;
12	2	Entitlement report	2	Diagram3	Elevated users	Elevated_users.JSON	\N	\N	0
13	3	Discovery report	1	JournalCheck	Recommendations	Recommendations.JSON	\N	\N	0
15	3	Risk report	1	JournalCheck	Real_time_alerts	Real_time_alerts.JSON	\N	\N	0
16	3	Executive report	1	ListCheck	Historical_alerts	Historical_alerts.JSON	\N	\N	0
18	3	FAM Report	1	ListCheck	Historical_alerts	Historical_alerts.JSON	\N	\N	0
7	2	Access log report:	0	ListOl	historicalthreats	Number_of_cases_Access_log_report.JSON, Access_log_report.JSON	select count(*) from THREATS.session_threats_history where status = 'Protext abandoned'	0	0
9	2	DAM Report:	0	ListOl	Predicted_threats	Predicted_threats.JSON	SELECT COALESCE(AVG(count), 0) AS count \nFROM (\n    SELECT \n        COUNT(session_id) AS count, \n        entry_date::date AS date, \n        EXTRACT(HOUR FROM entry_date) AS hour \n    FROM THREATS.session_threats_history  \n    GROUP BY entry_date::date, EXTRACT(HOUR FROM entry_date)\n) A\nWHERE A.hour = EXTRACT(HOUR FROM CURRENT_TIMESTAMP)	0	0
8	2	Suspicious activity report:	0	ListOl	Current_threats	Number_of_threats.JSON,Number_of_suspicious_transactions.JSON,Unusual_transactions.JSON,Suspicious_transactions.JSON,Suspicious_threats.JSON,Unusual_query_patterns.JSON,Failed_login_attempts.JSON,privileged_accounts_in_unexpected_manner.JSON	select  count(*) from THREATS.session_threats 	0	0
10	2	Compliance report	0	Database	Audit_logs:	Number_of_event_logs.JSON,audit_trails_database_logs.JSON	SELECT COUNT(*) AS count FROM \n(\n   SELECT seq, last_request_end_time, Query FROM \n   (\n       SELECT \n           ROW_NUMBER() OVER (PARTITION BY last_request_end_time ORDER BY last_request_end_time) AS seq,  \n           last_request_end_time, \n           Query   \n       FROM monitoring.active_transactions  \n       WHERE last_request_end_time > (SELECT MAX(last_request_end_time) FROM monitoring.active_transactions) - INTERVAL '1 minute'\n   ) A \n   WHERE seq = 1\n) B	49	0
11	2	Vulnerability report	0	Speedometer2	Audit_trails:	Audit_trails.JSON	SELECT COUNT(*)\nFROM monitoring.audit_trails_databaselogs\nWHERE entry_date > (SELECT MAX(entry_date) FROM monitoring.audit_trails_databaselogs) - INTERVAL '1 minute'\n	0	0
14	3	Analytics report	2	Diagram3	Security_violations:	Security_violations.JSON	SELECT SUM(cnt)\nFROM \n(\n   SELECT COUNT(*) AS cnt \n   FROM monitoring.server_hardening_Unused_Inactive_SQL_Server_Logins \n   WHERE entry_date > CURRENT_TIMESTAMP - INTERVAL '1 hour'\n   \n   UNION ALL \n   \n   SELECT COUNT(*) \n   FROM monitoring.sql_injection_Suspicious_Activity \n   WHERE entry_date > CURRENT_TIMESTAMP - INTERVAL '1 hour'\n   \n   UNION ALL \n   \n   SELECT COUNT(*) \n   FROM monitoring.database_unmasked_users \n   WHERE entry_date > CURRENT_TIMESTAMP - INTERVAL '1 hour'\n   \n   UNION ALL \n   \n   SELECT COUNT(*) \n   FROM monitoring.weak_passwords \n   WHERE entry_date > CURRENT_TIMESTAMP - INTERVAL '1 hour'\n) SECURITY_VIOLATIONS	0	0
3	1	Unknown TCP connections:	0	Hourglass	yesterday	Number_of_unknown_tcp_connections.JSON,Unknown_tcp_connections.JSON,\nAllowed_Connections.JSON	SELECT\n    COUNT(*) AS Number\nFROM monitoring.TCP_connections Con\nJOIN\n(\n    SELECT DISTINCT client_net_address \n    FROM monitoring.TCP_connections   \n    WHERE connect_time < Now() - INTERVAL '5 minutes'\n) STAT_CONNECTIONS ON Con.client_net_address = STAT_CONNECTIONS.client_net_address\nWHERE connect_time > (SELECT MAX(connect_time) FROM monitoring.TCP_connections) - INTERVAL '5 minutes'\n\n	0	0
1	1	SQL injections:	0	ListCheck	group-policy	sql_injection_transactions.JSON,SQL_injection_Transaction_requests.JSON	select sum(cnt) from \n(\nSELECT count(*)cnt FROM monitoring.sql_injection_suspicious_activity\nunion all \nSELECT count(*) FROM monitoring.injection_requests\n) a	0	0
5	1	Sensitive data:	0	ListOl	Total_requests	Number_of_sensitive_fields.JSON,cases_of_sensitive_data_usage.JSON,sensitive_schema.JSON,sensitive_schema_in_use.JSON	SELECT COUNT(*) FROM monitoring.transaction_requests WHERE last_request_end_time > (SELECT max(last_request_end_time) FROM monitoring.transaction_requests) - INTERVAL '1 minute'	0	0
6	1	Suspicous transactions:	0	ListOl	Allowed_requests	Number_of_suspicious_transactions.JSON,Suspicious_transactions.JSON	SELECT COUNT(*) \nFROM monitoring.transaction_requests  \nWHERE last_request_end_time > (SELECT MAX(last_request_end_time) FROM monitoring.transaction_requests) - INTERVAL '1 minute'\n	0	0
2	1	Blocked transactions:	0	Hourglass	blocked_transactions	Number_of_Blocked_connections.JSON,Blocked_Transactions.JSON	SELECT count(*) from \n(\n  select distinct status = 'Found unknown IP ADDRESS', w.server, client_net_address, Login_name, local_tcp_port, connect_time \n  FROM monitoring.transaction_requests w\n  JOIN \n  (\n    select SERVER, client_net_address, session_id, local_tcp_port, connect_time FROM \n    (\n      SELECT \n        row_number() OVER (PARTITION BY server, client_net_address ORDER BY connect_time DESC) AS SEQ, \n        SERVER, \n        session_id,\n        client_net_address, \n        local_tcp_port, \n        connect_time \n      FROM monitoring.tcp_connections c \n      WHERE (\n        last_read > (\n          SELECT MAX(last_read) FROM monitoring.tcp_connections b WHERE c.server = b.server\n        ) - INTERVAL '1 minute'\n        OR\n        last_write > (\n          SELECT MAX(last_write) FROM monitoring.tcp_connections b WHERE c.server = b.server\n        ) - INTERVAL '1 minute'\n      )\n      AND connect_time > (\n        SELECT MAX(connect_time) FROM monitoring.tcp_connections\n      ) - INTERVAL '1 minute'\n      AND client_net_address NOT IN (\n        SELECT client_net_address FROM monitoring.tcp_connections \n        WHERE connect_time < (\n          SELECT MAX(connect_time) FROM monitoring.tcp_connections\n        ) - INTERVAL '1 day'\n      )\n    ) C \n    WHERE SEQ = 1\n  ) A ON A.server = w.server AND A.session_id = w.session_id\n) A\nLEFT OUTER JOIN \n(\n  SELECT 'Killed Connection' AS Status, server, client_net_address, Login_name, session_id \n  FROM \n  (\n    SELECT \n      row_number() OVER (PARTITION BY W.server, client_net_address ORDER BY W.SERVER) AS SEQ,\n      W.SERVER, \n      LOGIN_NAME,\n      client_net_address, \n      A.session_id\n    FROM monitoring.transaction_requests w\n    JOIN \n    (\n      SELECT SERVER, client_net_address, session_id FROM \n      (\n        SELECT \n          row_number() OVER (PARTITION BY server, client_net_address ORDER BY SERVER) AS SEQ,\n          server, \n          session_id,\n          client_net_address\n        FROM monitoring.tcp_connections c\n        WHERE (\n          last_read > (\n            SELECT MAX(last_read) FROM monitoring.tcp_connections b WHERE c.server = b.server\n          ) - INTERVAL '1 minute'\n          OR\n          last_write > (\n            SELECT MAX(last_write) FROM monitoring.tcp_connections b WHERE c.server = b.server\n          ) - INTERVAL '1 minute'\n        )\n        AND connect_time > (\n          SELECT MAX(connect_time) FROM monitoring.tcp_connections\n        ) - INTERVAL '1 minute'\n        AND client_net_address NOT IN (\n          SELECT client_net_address FROM monitoring.tcp_connections \n          WHERE connect_time < (\n            SELECT MAX(connect_time) FROM monitoring.tcp_connections\n          ) - INTERVAL '1 day'\n        )\n      ) C \n      WHERE SEQ = 1\n    ) A ON A.server = w.server AND A.session_Id = w.session_id\n  ) D \n  WHERE D.SEQ = 1\n) B ON B.server = A.server AND B.client_net_address = A.client_net_address	0	0
4	1	Audit events:	0	ShieldLock	Blocked_requests	Number_of_event_logs.JSON,audit_trails_database_logs.JSON	SELECT count(*) FROM \n(\n  SELECT DISTINCT \n    'Found unknown IP ADDRESS' AS status, \n    w.server, \n    client_net_address, \n    Login_name, \n    local_tcp_port, \n    connect_time \n  FROM monitoring.TRaNSACTION_requests w\n  JOIN \n  (\n    SELECT SERVER, client_net_address, session_id, local_tcp_port, connect_time FROM \n    (\n      SELECT \n        row_number() OVER (PARTITION BY server, client_net_address ORDER BY connect_time DESC) AS SEQ, \n        SERVER, \n        session_id, \n        client_net_address, \n        local_tcp_port, \n        connect_time \n      FROM monitoring.TCP_connections c\n      WHERE (\n        last_read > (SELECT MAX(last_read) FROM monitoring.TCP_connections b WHERE c.server = b.server) - INTERVAL '1 minute'\n        OR \n        last_write > (SELECT MAX(last_write) FROM monitoring.TCP_connections b WHERE c.server = b.server) - INTERVAL '1 minute'\n      )\n      AND connect_time > (SELECT MAX(connect_time) FROM monitoring.TCP_connections) - INTERVAL '1 minute'\n      AND client_net_address NOT IN (\n        SELECT client_net_address \n        FROM monitoring.TCP_connections \n        WHERE CONNECT_TIME < (SELECT MAX(connect_time) FROM monitoring.TCP_connections) - INTERVAL '1 day'\n      )\n    ) C \n    WHERE SEQ = 1\n  ) A ON A.server = w.server AND A.session_Id = w.session_id \n) A\nLEFT OUTER JOIN \n(\n  SELECT \n    'Killed Connection' AS Ststus, \n    server, \n    client_net_address, \n    Login_name, \n    session_id\n  FROM \n  (\n    SELECT \n      row_number() OVER (PARTITION BY W.server, client_net_address ORDER BY W.SERVER) AS SEQ, \n      W.SERVER, \n      LOGIN_NAME, \n      client_net_address, \n      A.session_id\n    FROM monitoring.transaction_requests w\n    JOIN \n    (\n      SELECT SERVER, client_net_address, session_id FROM \n      (\n        SELECT \n          row_number() OVER (PARTITION BY server, client_net_address ORDER BY SERVER) AS SEQ, \n          server, \n          session_id, \n          client_net_address \n        FROM monitoring.TCP_connections c\n        WHERE (\n          last_read > (SELECT MAX(last_read) FROM monitoring.TCP_connections b WHERE c.server = b.server) - INTERVAL '1 minute'\n          OR \n          last_write > (SELECT MAX(last_write) FROM monitoring.TCP_connections b WHERE c.server = b.server) - INTERVAL '1 minute'\n        )\n        AND connect_time > (SELECT MAX(connect_time) FROM monitoring.TCP_connections) - INTERVAL '1 minute'\n        AND client_net_address NOT IN (\n          SELECT client_net_address \n          FROM   \n\t\t  monitoring.TCP_connections \n          WHERE CONNECT_TIME < (SELECT MAX(connect_time) FROM monitoring.TCP_connections) - INTERVAL '1 hour'\n        )\n      ) C \n      WHERE SEQ = 1\n    ) A ON A.server = w.server AND A.session_Id = w.session_id \n  ) D \n  WHERE D.SEQ = 1\n) B ON B.server = A.server AND B.client_net_address = A.client_net_address\n	0	0
17	3	Workflow report	0	ListCheck	Sql_Injection:	sql_injection_Transactions.JSON	SELECT COUNT(*)\nFROM monitoring.injection_requests \nWHERE entry_date > (SELECT MAX(entry_date) FROM monitoring.injection_requests) - INTERVAL '1 minute'\n	0	0
\.
INSERT INTO widget.report_items_indicators (row_id, report_item_id, label, risk, icon, goto, detailfiles, query, kpi, threshold_critical)
SELECT row_id, report_item_id, label, risk, icon, goto, detailfiles, query, kpi, threshold_critical FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.report_items_indicators);
DROP TABLE _stg_load;

SELECT setval('widget.report_items_indicators_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.report_items_indicators),1), (SELECT count(*) FROM widget.report_items_indicators) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'report_items_indicators'
          AND con.conname = 'report_items_indicators_pkey') THEN
        ALTER TABLE ONLY widget.report_items_indicators
    ADD CONSTRAINT report_items_indicators_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
