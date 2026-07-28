-- Functions, procedures, views and materialized views.
-- Emitted in pg_dump dependency order; functions/procedures/views use
-- CREATE OR REPLACE and matviews use IF NOT EXISTS, so re-runs are safe.

CREATE OR REPLACE PROCEDURE config.action_type_activate(IN p_server character varying, IN p_action_type_id integer, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN	    
        update config.action_types
		set is_active = p_is_active where
            server = p_server and row_id = p_action_type_id;
END;
$$;

CREATE OR REPLACE PROCEDURE config.action_type_activate(IN p_server character varying, IN p_action_type_id integer, IN p_is_active integer)
    LANGUAGE plpgsql
    AS $$
BEGIN	    
    IF p_is_active = 1 THEN 
        UPDATE config.action_types
        SET is_active = true 
        WHERE server = p_server 
          AND row_id = p_action_type_id;			
    ELSIF p_is_active = 0 THEN 
        UPDATE config.action_types
        SET is_active = false 
        WHERE server = p_server 
          AND row_id = p_action_type_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE config.action_type_update(IN ap_server character varying, IN p_action_type_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN	    
        INSERT INTO config.action_types (
            server, action_type_id
        )
        VALUES (            
            p_server, p_action_type_id
        );                
END;
$$;

CREATE OR REPLACE PROCEDURE config.addrecipients(IN p_mail_config_id integer, IN p_recipients text)
    LANGUAGE plpgsql
    AS $$    
BEGIN
    insert into config.mail_groups ( mail_config_id , group_name  ,  recipients , is_active)
	select p_mail_config_id , p_recipients, p_recipients , true
	where p_recipients not in (select recipients from config.mail_groups where mail_config_id = p_mail_config_id);
    
    
END;
$$;

CREATE OR REPLACE PROCEDURE config.delete_mail_config(IN p_row_id integer, IN p_force boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_group_count integer;
BEGIN
    SELECT COUNT(*) INTO v_group_count
      FROM config.mail_groups
     WHERE mail_config_id = p_row_id;

    IF v_group_count > 0 THEN
        IF p_force THEN
            DELETE FROM config.mail_groups WHERE mail_config_id = p_row_id;
        ELSE
            RAISE EXCEPTION
                'mail_config % is referenced by % mail_groups; pass p_force=>true to cascade',
                p_row_id, v_group_count;
        END IF;
    END IF;

    DELETE FROM config.mail_config WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'mail_config row_id % not found', p_row_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE config.delete_mail_group(IN p_row_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM config.mail_groups WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'mail_groups row_id % not found', p_row_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION config.fn_risk_register_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION config.get_local_ip() RETURNS inet
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_local_ip varchar(50);
BEGIN
    SELECT value INTO p_local_ip
    FROM config.global_params
    WHERE key = 'local_ip';

    RETURN p_local_ip::inet;  -- cast to inet
END;
$$;

CREATE OR REPLACE PROCEDURE config.mail_config(IN p_smtp_server text, IN p_smtp_user text, IN p_smtp_password text, IN p_smtp_port integer, IN p_tls boolean, IN p_smtp_sender text)
    LANGUAGE plpgsql
    AS $$
    
BEGIN
    insert into config.mail_config (smtp_server , smtp_user ,  smtp_password , smtp_port  ,tls  , mail_sender)
	select p_smtp_server , p_smtp_user , p_smtp_password , p_smtp_port , p_tls ,p_smtp_sender 
	where p_smtp_server not in (select smtp_server from config.mail_config where smtp_server = p_smtp_server);
    
    
END;
$$;

CREATE OR REPLACE PROCEDURE config.mailconfig(IN p_smtp_server text, IN p_smtp_user text, IN p_smtp_password text, IN p_smtp_port integer, IN p_tls boolean, IN p_smtp_sender text)
    LANGUAGE plpgsql
    AS $$
    
BEGIN
    insert into config.mail_config (smtp_server , smtp_user ,  smtp_password , smtp_port  ,tls  , smtp_sender)
	select p_smtp_server , p_smtp_user , p_smtp_password , p_smtp_port , p_tls ,p_smtp_sender 
	where p_smtp_server not in (select smtp_server from config.mail_config where smtp_server = p_smtp_server);
    
    
END;
$$;

CREATE OR REPLACE PROCEDURE config.retention_policy_keep_update(IN p_server character varying, IN p_keep_days integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    
BEGIN	
    update config.retention_policy set days_to_keep = p_keep_days  where server = p_server;
	
END;
$$;

CREATE OR REPLACE PROCEDURE config.retention_policy_update(IN p_server character varying, IN p_table_name character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_id INT;
BEGIN
	select v_new_id = (SELECT count(*) from config.retention_policy where server = p_server and table_name = p_table_name);
    IF v_new_id =0  THEN
    
        -- Insert into metrics.servers and capture the new row_id
        INSERT INTO config.retention_policy (
            server, table_name
        )
        VALUES (            
            p_server, p_table_name
        );                
    END IF;
	
END;
$$;

CREATE OR REPLACE PROCEDURE config.save_mail_config(INOUT p_row_id integer, IN p_smtp_server character varying, IN p_smtp_port integer, IN p_smtp_user character varying, IN p_smtp_password character varying, IN p_tls boolean, IN p_mail_sender text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_row_id IS NULL THEN
        INSERT INTO config.mail_config
            (smtp_server, smtp_port, smtp_user, smtp_password, tls, mail_sender)
        VALUES
            (p_smtp_server, p_smtp_port, p_smtp_user, p_smtp_password,
             COALESCE(p_tls, true), p_mail_sender)
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE config.mail_config
           SET smtp_server   = p_smtp_server,
               smtp_port     = p_smtp_port,
               smtp_user     = p_smtp_user,
               smtp_password = p_smtp_password,
               tls           = COALESCE(p_tls, tls),
               mail_sender   = p_mail_sender
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'mail_config row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE config.save_mail_details(INOUT p_config_id integer, INOUT p_group_id integer, IN p_smtp_server character varying, IN p_smtp_port integer, IN p_smtp_user character varying, IN p_smtp_password character varying, IN p_tls boolean, IN p_mail_sender text, IN p_group_name text, IN p_recipients text, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    CALL config.save_mail_config(
        p_config_id, p_smtp_server, p_smtp_port,
        p_smtp_user, p_smtp_password, p_tls, p_mail_sender
    );

    CALL config.save_mail_group(
        p_group_id, p_config_id, p_group_name, p_recipients, p_is_active
    );
END;
$$;

CREATE OR REPLACE PROCEDURE config.save_mail_group(INOUT p_row_id integer, IN p_mail_config_id integer, IN p_group_name text, IN p_recipients text, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_mail_config_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM config.mail_config WHERE row_id = p_mail_config_id)
    THEN
        RAISE EXCEPTION 'mail_config_id % does not exist', p_mail_config_id;
    END IF;

    IF p_row_id IS NULL THEN
        INSERT INTO config.mail_groups
            (mail_config_id, group_name, recipients, is_active)
        VALUES
            (p_mail_config_id, p_group_name, p_recipients, COALESCE(p_is_active, true))
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE config.mail_groups
           SET mail_config_id = p_mail_config_id,
               group_name     = p_group_name,
               recipients     = p_recipients,
               is_active      = COALESCE(p_is_active, is_active)
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'mail_groups row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE config.set_local_ip(IN p_value character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM config.global_params
        WHERE "key" = 'local_ip'
    ) THEN
        INSERT INTO config.global_params ("key", value)
        VALUES ('local_ip', p_value);
    ELSE
        UPDATE config.global_params
        SET value = p_value
        WHERE "key" = 'local_ip';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION flowchart.color_by_threshold(p_sql text, p_threshold_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    KPI numeric := 0;
    p_value_start numeric;
    p_value_end numeric;
BEGIN
    -- Execute dynamic SQL
    IF p_sql IS NOT NULL THEN
        EXECUTE p_sql INTO KPI;
    END IF;

    -- Get threshold values
    SELECT value_start, value_end
    INTO p_value_start, p_value_end
    FROM config.thresholds
    WHERE row_id = p_threshold_id;

    -- If threshold not found → default color
    IF p_value_start IS NULL THEN
        RETURN 'blue';
    END IF;

    -- Compare KPI against threshold
    IF KPI BETWEEN p_value_start AND COALESCE(p_value_end, 9999999999999) THEN
        RETURN 'green';
    ELSE
        RETURN 'red';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION flowchart.execute_json_query(p_sql text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    result jsonb := null;
BEGIN
    IF p_sql IS NOT NULL THEN
        EXECUTE p_sql INTO result;
    END IF;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION flowchart.execute_numeric_query(p_sql text) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    result numeric := 0;
BEGIN
    IF p_sql IS NOT NULL THEN
        EXECUTE p_sql INTO result;
    END IF;

    RETURN COALESCE(result, -1);
END;
$$;

CREATE OR REPLACE PROCEDURE jobs.job_schedule_insert(IN p_report_id integer, IN p_job_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN	    
		update jobs.job_schedules set last_run = Now()   where report_id  = p_report_id and Schedule_id = p_job_id;
        insert into  jobs.job_schedules
		(
			report_id , Schedule_id , next_run			
		)
		select p_report_id , p_job_id  , 
		(
			
select next_run from 
(
  SELECT        row_number() over (partition  by r.row_id , j.row_id order by js.last_run desc ) seq , 
  				CASE
                    WHEN (j.occurance = 'daily'::text) THEN Now() + '1 day'::interval
                    WHEN (j.occurance = 'weekly'::text) THEN Now() + '7 days'::interval
                    WHEN (j.occurance = 'monthly'::text) THEN Now() + '1 mon'::interval
                    ELSE NULL::timestamp without time zone
                END AS next_run ,  r.row_id report_id, j.row_id  job_id
				
           FROM config.reports r
             JOIN config.reports_jobs rj ON rj.report_id = r.row_id
             JOIN jobs.jobs j ON j.row_id = rj.job_id
             JOIN config.mail_jobs mj ON mj.job_id = rj.job_id
             JOIN config.mail_config mc ON mc.row_id = mj.mail_id
             JOIN config.mail_groups mg ON mg.mail_config_id = mc.row_id
             LEFT JOIN jobs.job_schedules js ON js.report_id = r.row_id AND js.schedule_id = j.row_id 
			) where seq = 1			 
			and report_id=p_report_id
			and job_id = p_job_id
		);
		
END;
$$;

CREATE OR REPLACE FUNCTION log.fn_incidents_gdpr_due() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.involves_personal_data = TRUE AND NEW.gdpr_notification_due IS NULL THEN
        NEW.gdpr_notification_due := NEW.detected_at + INTERVAL '72 hours';
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.customized_metrics_delete(IN p_metrics_name text, IN p_update_mode integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if  exists (SELECT 1 FROM metrics.custom_metrics where LOWER(metric_name) = LOWER(p_metrics_name) )  and p_update_mode = 1 THEN
		delete from  metrics.custom_metrics where LOWER(metric_name) = LOWER(p_metrics_name);
	end if;
END;
$$;

CREATE OR REPLACE FUNCTION metrics.disk_free_bytes() RETURNS bigint
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE v bigint;
BEGIN
    IF to_regclass('metrics._disk_free') IS NULL THEN
        RETURN NULL;
    END IF;
    BEGIN
        SELECT free_bytes::bigint INTO v FROM metrics._disk_free LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        v := NULL;
    END;
    RETURN v;
END $$;

CREATE OR REPLACE FUNCTION metrics.log_server_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_server_id  uuid;
    v_servername text;
    v_old        jsonb;
    v_new        jsonb;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_server_id  := OLD.server_id;
        v_servername := OLD.servername;
        v_old        := to_jsonb(OLD) - 'password';
    ELSIF TG_OP = 'INSERT' THEN
        v_server_id  := NEW.server_id;
        v_servername := NEW.servername;
        v_new        := to_jsonb(NEW) - 'password';
    ELSE  -- UPDATE
        IF to_jsonb(OLD) IS NOT DISTINCT FROM to_jsonb(NEW) THEN
            RETURN NULL;                          -- nothing actually changed
        END IF;
        v_server_id  := NEW.server_id;
        v_servername := NEW.servername;
        v_old        := to_jsonb(OLD) - 'password';
        v_new        := to_jsonb(NEW) - 'password';
    END IF;

    INSERT INTO metrics.server_log (operation, changed_by, server_id, servername, old_data, new_data)
    VALUES (TG_OP, current_user, v_server_id, v_servername, v_old, v_new);

    RETURN NULL;  -- AFTER trigger: return value ignored
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.process_activate(IN p_process_name text, IN p_interval integer, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_process_name IS NOT NULL AND p_is_active IS NOT NULL THEN
            UPDATE metrics.registered_processes
            SET is_active = p_is_active , 
				interval = p_interval
            WHERE process_name = p_process_name;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION metrics.retention_overview() RETURNS TABLE(category text, item text, data_size text, data_bytes bigint, row_count bigint, space_free text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_free_txt text := COALESCE(pg_size_pretty(metrics.disk_free_bytes()), 'n/a');
BEGIN
    RETURN QUERY SELECT 'TABLESPACE'::text,
        ('pg_default (' || current_setting('data_directory') || ')')::text,
        pg_size_pretty(pg_tablespace_size('pg_default')),
        pg_tablespace_size('pg_default')::bigint,
        NULL::bigint,
        v_free_txt;

    RETURN QUERY SELECT 'TABLE'::text, 'alerts.alert_log'::text,
        pg_size_pretty(pg_total_relation_size('alerts.alert_log')),
        pg_total_relation_size('alerts.alert_log')::bigint,
        (SELECT count(*) FROM alerts.alert_log),
        v_free_txt;

    RETURN QUERY SELECT 'TABLE'::text, 'alerts.mail_alert_log'::text,
        pg_size_pretty(pg_total_relation_size('alerts.mail_alert_log')),
        pg_total_relation_size('alerts.mail_alert_log')::bigint,
        (SELECT count(*) FROM alerts.mail_alert_log),
        v_free_txt;

    RETURN QUERY
        SELECT 'METRIC'::text, t.metric_name::text,
               pg_size_pretty(sum(pg_column_size(t.*))::bigint),
               sum(pg_column_size(t.*))::bigint,
               count(*),
               v_free_txt
        FROM monitoring.general_metric_metadata_results t
        GROUP BY t.metric_name
        ORDER BY sum(pg_column_size(t.*)) DESC;
END $$;

CREATE OR REPLACE PROCEDURE metrics.server_activate(IN p_server_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_is_active boolean;
BEGIN
    IF p_server_name IS NULL THEN
        RAISE EXCEPTION 'p_server_name cannot be NULL';
    END IF;

    SELECT is_active
    INTO p_is_active
    FROM metrics.servers
    WHERE servername = p_server_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Server % not found', p_server_name;
    END IF;

    UPDATE metrics.servers
    SET is_active = NOT p_is_active
    WHERE servername = p_server_name;
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.server_activate(IN p_server_name text, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if p_server_name is not null and p_is_active is not null then 
		p_is_active := NOT p_is_active;
    	UPDATE metrics.servers
    	SET is_active = p_is_active 
    	WHERE servername = p_server_name;
	end if;
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.server_activate(IN p_server_name text, IN p_is_active integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_server_name IS NOT NULL AND p_is_active IS NOT NULL THEN
        IF p_is_active = 1 THEN
            UPDATE metrics.servers
            SET is_active = false
            WHERE server = p_server_name;
        ELSIF p_is_active = 0 THEN
            UPDATE metrics.servers
            SET is_active = true
            WHERE server = p_server_name;
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.upsert_customized_metrics(IN p_metrics_name text, IN p_query text, IN p_dbvendor text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if  not exists (SELECT 1 FROM metrics.custom_metrics where LOWER(metric_name) = LOWER(p_metrics_name) ) THEN
		insert into metrics.custom_metrics  ( category_id, metric_name, query, description, is_active , db_vendor )
		select 1 , p_metrics_name , p_query , p_metrics_name , True , p_dbvendor;
	end if;
END;
$$;

CREATE OR REPLACE PROCEDURE metrics.upsert_monitored_server(IN p_ip_address text, IN p_server_name text, IN p_db_vendor text, IN p_db_version text, IN p_auth_type text, IN p_username text, IN p_password text, IN p_service_name text, IN p_port integer, IN p_add_modify_delete text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_id INT ;
	server_id_to_delete int;	
BEGIN
    IF p_add_modify_delete != 'delete' AND NOT EXISTS (
        SELECT 1 FROM metrics.servers WHERE servername = p_server_name
    ) THEN
    
        -- Insert into metrics.servers and capture the new row_id
        INSERT INTO metrics.servers (
            server, servername, db_vendor, db_version, auth_type, username, password , service_name , driver,port
        )
        VALUES (
            p_ip_address, p_server_name, p_db_vendor, p_db_version,
            p_auth_type, p_username, p_password , p_service_name , 'ODBC+Driver+17+for+SQL+Server',p_port
        )
        RETURNING row_id INTO v_new_id;
        
        -- Insert into metrics.server_routines (example) using the captured ID
        INSERT INTO metrics.servers_routines (server_id, routine_id, scheduler_id)
        SELECT v_new_id, row_id, 1
        FROM metrics.routines
        WHERE lower(db_version) = lower(p_db_vendor)
		and not  exists 
		(
 			SELECT 1
    		FROM metrics.servers_routines sr
    		WHERE sr.server_id = v_new_id
		);
		
    	insert into config.retention_policy (server , table_name)		
		select p_ip_address , table_schema || '.'|| table_name from information_schema.tables
		where not exists 
		(
			select  1  from config.retention_policy where p_ip_address=server
		);
		insert into config.action_types( server  , action_name  , action_description  , is_active) 
		select server  , action_name  , action_description  , is_active  from config.action_types
		where server = 'unknown';

    ELSE
        -- Delete if exists and requested
        select row_id into server_id_to_delete  from  metrics.servers WHERE servername = p_server_name;
		delete from metrics.servers_routines where  server_id =  server_id_to_delete;
		DELETE FROM metrics.servers WHERE servername = p_server_name;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION monitoring.build_flowchart(p_issue_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    result jsonb;
BEGIN

WITH ordered_data AS (
    SELECT
        server,
        root_cause_id || '-' || root_cause_number AS root_id,
        root_cause_name,
        step_number,
        row_number() OVER (ORDER BY step_number) AS rn
    FROM monitoring.v_rootcauses
    WHERE issue_id = p_issue_id
),

nodes AS (

    -- 1️⃣ Start Node (Server)
    SELECT
        jsonb_build_object(
            'id', '1',
            'type', 'input',
            'data', jsonb_build_object(
                'label', (SELECT server FROM ordered_data LIMIT 1)
            ),
            'style', jsonb_build_object(
                'nodeType', 'start'
            )
        ) AS node_json,
        1 AS order_col

    UNION ALL

    -- 2️⃣ Root Cause Nodes
    SELECT
        jsonb_build_object(
            'id', (rn + 1)::text,
            'data', jsonb_build_object(
                'label', root_cause_name
            ),
            'style', jsonb_build_object(
                'nodeType', 'process'
            )
        ),
        rn + 1
    FROM ordered_data
),

edges AS (

    -- Edge from Server → First Step
    SELECT
        jsonb_build_object(
            'id', 'e1-2',
            'source', '1',
            'target', '2',
            'animated', true
        ) AS edge_json,
        1 AS order_col

    UNION ALL

    -- Sequential Edges
    SELECT
        jsonb_build_object(
            'id', 'e' || (rn + 1) || '-' || (rn + 2),
            'source', (rn + 1)::text,
            'target', (rn + 2)::text
        ),
        rn + 1
    FROM ordered_data
)

SELECT jsonb_build_object(
    'charts',
    jsonb_build_object(
        'FlowChart',
        jsonb_build_object(
            'direction', 'UB',
            'nodes', (
                SELECT jsonb_agg(node_json ORDER BY order_col)
                FROM nodes
            ),
            'edges', (
                SELECT jsonb_agg(edge_json ORDER BY order_col)
                FROM edges
            )
        )
    )
)
INTO result;

RETURN result;

END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.compare_expensive_transactions()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Drop and recreate temporary tables
    DROP TABLE IF EXISTS _t_old;
    CREATE TEMP TABLE _t_old AS 
    SELECT 
        elem->>'avg_cpu_ms' AS avg_cpu_ms, 
        elem->>'query_text' AS query, 
        elem->>'database_name' AS database_name,
        (elem->>'avg_duration_ms')::NUMERIC(10,2) AS avg_duration_ms,
        elem->>'execution_count' AS execution_count,
        elem->>'max_duration_ms' AS max_duration_ms,
        elem->>'avg_logical_reads' AS avg_logical_reads,
        mqp.observed_at, 
        mqp.columns, 
        mqp.tables, 
        mqp.literal, 
        mqp.condition, 
        mqp.joins, 
        mqp.func 	
    FROM monitoring.general_metric_metadata_results gmmr
    LEFT JOIN LATERAL jsonb_array_elements(gmmr.metric_metadata::jsonb) elem ON true
    JOIN monitoring.metric_query_parsing mqp ON mqp.query_id = gmmr.row_id
    WHERE gmmr.metric_name = 'expensive_transactions'
      AND (elem->>'avg_duration_ms')::NUMERIC(10,2) < 1000;

    DROP TABLE IF EXISTS _t_new;
    CREATE TEMP TABLE _t_new AS
    SELECT 
        server,  
        avg_cpu_ms, 
        query, 
        avg_duration_ms, 
        execution_count, 
        max_duration_ms, 
        avg_logical_reads, 
        last_execution_time,  
        observed_at, 
        columns, 
        tables, 
        literal, 
        condition, 
        joins, 
        func
    FROM (
        SELECT 
            gmmr.row_id, 		
            gmmr.server AS server, 
            elem->>'avg_cpu_ms' AS avg_cpu_ms, 
            elem->>'query_text' AS query, 
            elem->>'database_name' AS database_name,
            (elem->>'avg_duration_ms')::NUMERIC(10,2) AS avg_duration_ms,
            elem->>'execution_count' AS execution_count,
            elem->>'max_duration_ms' AS max_duration_ms,
            elem->>'avg_logical_reads' AS avg_logical_reads,
            mqp.observed_at, 
            mqp.columns, 
            mqp.tables, 
            mqp.literal, 
            mqp.condition, 
            mqp.joins, 
            mqp.func,
            to_timestamp((elem->>'last_execution_time')::BIGINT / 1000) AS last_execution_time
        FROM monitoring.general_metric_metadata_results gmmr
        LEFT JOIN LATERAL jsonb_array_elements(gmmr.metric_metadata::jsonb) elem ON true
        JOIN monitoring.metric_query_parsing mqp ON mqp.query_id = gmmr.row_id
        WHERE gmmr.metric_name = 'expensive_transactions'
    ) a
    WHERE avg_duration_ms > 1000;

    -- Return comparison results
    RAISE NOTICE 'Expensive transactions comparison results:';
    PERFORM 
        _t_new.avg_cpu_ms, 
        _t_new.query, 
        _t_new.database_name,
        _t_new.avg_duration_ms,
        _t_new.execution_count,
        _t_new.max_duration_ms,
        _t_new.avg_logical_reads,
        _t_new.observed_at,
        _t_new.columns, 
        _t_new.tables,
        _t_new.literal,
        _t_new.condition,
        _t_new.joins, 
        _t_new.func
    FROM _t_new
    JOIN _t_old ON _t_old.tables = _t_new.tables;

END;
$$;

CREATE OR REPLACE FUNCTION monitoring.execute_queries_and_update_counts() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_queries CURSOR FOR 
        SELECT row_id , label, query 
        FROM  widget.report_items_indicators
        WHERE query IS NOT NULL AND query != '' ;
    
    rec RECORD;
    row_id INTEGER;
	query_count INTEGER;
    dynamic_sql TEXT;
BEGIN
    -- Open cursor and loop through each query
    FOR rec IN cur_queries LOOP
        BEGIN
            -- Prepare the dynamic SQL
            dynamic_sql := rec.query;
            
            -- Execute the query and get the count
            EXECUTE dynamic_sql INTO query_count;
            
            -- Update the count field for this record
            UPDATE widget.report_items_indicators rii
            SET KPI = query_count
            WHERE rii.row_id = rec.row_id;
            
            -- Log successful execution (optional)
            RAISE NOTICE 'Query ID % executed successfully. Count: %', rec.row_id, query_count;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Handle errors gracefully
                UPDATE widget.report_items_indicators rii
                SET KPI = 0 -- Use -1 to indicate error                 
                WHERE rii.row_id = rec.row_id;
                
                RAISE NOTICE 'Error executing query ID %: %', rec.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Finished processing all queries';
END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.generate_all_root_cause_views(IN p_owner text DEFAULT 'enterprisedb'::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rc text;
    v_count int := 0;
    v_errors int := 0;
BEGIN
    FOR v_rc IN
        SELECT DISTINCT r.metric_name
          FROM monitoring.general_metric_metadata_results r
         WHERE r.metric_metadata IS NOT NULL
           AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
           AND jsonb_array_length(r.metric_metadata::jsonb) > 0
         ORDER BY r.metric_name
    LOOP
        BEGIN
            CALL monitoring.generate_root_cause_view(v_rc, p_owner);
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Failed for %: %', v_rc, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Generated/refreshed % views (% errors)', v_count, v_errors;
END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.generate_root_cause_view(IN p_root_cause_id text, IN p_owner text DEFAULT 'enterprisedb'::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_view_name    text;
    v_full_name    text;
    v_sample       jsonb;
    v_first_elem   jsonb;
    v_keys         text[];
    v_select_cols  text;
    v_ddl          text;
    v_key          text;
BEGIN
    IF p_root_cause_id IS NULL OR length(trim(p_root_cause_id)) = 0 THEN
        RAISE EXCEPTION 'root_cause_id must be provided';
    END IF;

    -- Most recent non-empty metric_metadata array for this root cause
    SELECT r.metric_metadata::jsonb
      INTO v_sample
      FROM monitoring.general_metric_metadata_results r
     WHERE r.metric_name = p_root_cause_id
       AND r.metric_metadata IS NOT NULL
       AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
       AND jsonb_array_length(r.metric_metadata::jsonb) > 0
     ORDER BY r.entry_date DESC
     LIMIT 1;

    IF v_sample IS NULL THEN
        RAISE NOTICE 'No sample metric_metadata for %, skipping', p_root_cause_id;
        RETURN;
    END IF;

    v_first_elem := v_sample -> 0;
    IF jsonb_typeof(v_first_elem) <> 'object' THEN
        RAISE NOTICE 'metric_metadata[0] for % is not an object, skipping', p_root_cause_id;
        RETURN;
    END IF;

    -- Distinct keys, in insertion order from the sample element
    SELECT array_agg(k ORDER BY k)
      INTO v_keys
      FROM jsonb_object_keys(v_first_elem) k;

    v_view_name := monitoring.view_name_for_rc(p_root_cause_id);
    v_full_name := 'monitoring.' || quote_ident(v_view_name);

    -- Build select list
    v_select_cols := 'r.server';
    FOREACH v_key IN ARRAY v_keys LOOP
        v_select_cols := v_select_cols
            || E',\n       (j.value ->> ' || quote_literal(v_key) || ') AS '
            || quote_ident(v_key);
    END LOOP;
    v_select_cols := v_select_cols || E',\n       r.entry_date';

    v_ddl :=
        'CREATE OR REPLACE VIEW ' || v_full_name || ' AS' || E'\n' ||
        'SELECT ' || v_select_cols || E'\n' ||
        '  FROM monitoring.general_metric_metadata_results r' || E'\n' ||
        '  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)' || E'\n' ||
        ' WHERE r.metric_name = ' || quote_literal(p_root_cause_id);

    EXECUTE v_ddl;

    IF p_owner IS NOT NULL AND length(trim(p_owner)) > 0 THEN
        EXECUTE format('ALTER VIEW %s OWNER TO %I', v_full_name, p_owner);
    END IF;

    RAISE NOTICE 'Created/updated view % (% columns)',
        v_full_name, array_length(v_keys, 1);
END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.generate_shell_root_cause_view(IN p_root_cause_id text, IN p_owner text DEFAULT 'enterprisedb'::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_view_name text;
    v_full_name text;
    v_ddl       text;
BEGIN
    v_view_name := monitoring.view_name_for_rc(p_root_cause_id);
    v_full_name := 'monitoring.' || quote_ident(v_view_name);

    v_ddl :=
        'CREATE OR REPLACE VIEW ' || v_full_name || ' AS' || E'\n' ||
        'SELECT r.server,' || E'\n' ||
        '       r.metric_metadata,' || E'\n' ||
        '       r.entry_date' || E'\n' ||
        '  FROM monitoring.general_metric_metadata_results r' || E'\n' ||
        ' WHERE r.metric_name = ' || quote_literal(p_root_cause_id);

    EXECUTE v_ddl;

    IF p_owner IS NOT NULL AND length(trim(p_owner)) > 0 THEN
        EXECUTE format('ALTER VIEW %s OWNER TO %I', v_full_name, p_owner);
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.generate_views_from_rootcause(IN p_owner text DEFAULT 'enterprisedb'::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rc           text;
    v_has_data     boolean;
    v_typed        int := 0;
    v_shell        int := 0;
    v_errors       int := 0;
    v_current_view text;
BEGIN
    FOR v_rc IN
        SELECT root_cause_id FROM rootcause.root_causes ORDER BY root_cause_id
    LOOP
        BEGIN
            v_current_view := monitoring.view_name_for_rc(v_rc);

            SELECT EXISTS (
                SELECT 1
                  FROM monitoring.general_metric_metadata_results r
                 WHERE r.metric_name = v_rc
                   AND r.metric_metadata IS NOT NULL
                   AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
                   AND jsonb_array_length(r.metric_metadata::jsonb) > 0
                 LIMIT 1
            ) INTO v_has_data;

            -- If a shell view already exists for this RC and we're about
            -- to create a typed one with different columns, drop it first
            -- (CREATE OR REPLACE VIEW refuses column-set changes).
            IF v_has_data THEN
                EXECUTE format('DROP VIEW IF EXISTS monitoring.%I', v_current_view);
                CALL monitoring.generate_root_cause_view(v_rc, p_owner);
                v_typed := v_typed + 1;
            ELSE
                CALL monitoring.generate_shell_root_cause_view(v_rc, p_owner);
                v_shell := v_shell + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Failed for %: %', v_rc, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Generated: % typed, % shell, % errors',
                 v_typed, v_shell, v_errors;
END;
$$;

CREATE OR REPLACE FUNCTION monitoring.get_alert_log_resultset(p_root_cause_id text, p_time_from timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE(result json, entry_date timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- Guard empty / unsubstituted Grafana variable.
    IF p_root_cause_id IS NULL
       OR p_root_cause_id = ''
       OR p_root_cause_id LIKE '${%}'
    THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        (
            SELECT jsonb_object_agg(k, v)
            FROM jsonb_each(
                monitoring.jsonb_lower_keys(elem)
                || jsonb_build_object('server',     a.server,
                                      'risk_level', a.risk_level,
                                      'login_name', a.login_name)
            ) t(k, v)
            WHERE v IS DISTINCT FROM 'null'::jsonb
        )::json AS result,
        a.entry_date
    FROM alerts.alert_log a
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN jsonb_typeof(a.metadata) = 'array'  THEN a.metadata
            WHEN jsonb_typeof(a.metadata) = 'string' THEN
                 CASE WHEN jsonb_typeof((a.metadata #>> '{}')::jsonb) = 'array'
                      THEN (a.metadata #>> '{}')::jsonb
                      ELSE jsonb_build_array((a.metadata #>> '{}')::jsonb)
                 END
            ELSE jsonb_build_array(a.metadata)   -- object / scalar -> single element
        END
    ) elem
    WHERE a.root_cause_id = p_root_cause_id
      AND (p_time_from IS NULL OR a.entry_date > p_time_from)     -- pushed-down, index-friendly
      -- hide the dbdome monitoring account (its own collector session shows up
      -- in self-monitoring detections); checks both the column and the metadata.
      AND COALESCE(NULLIF(a.login_name, ''),
                   monitoring.jsonb_lower_keys(elem) ->> 'login_name')
            IS DISTINCT FROM 'dbdome_mon_usr';

EXCEPTION
    WHEN OTHERS THEN RETURN;
END;
$_$;

CREATE OR REPLACE FUNCTION monitoring.get_root_cause_resultset(p_root_cause_id text) RETURNS TABLE(result json, entry_date timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    IF p_root_cause_id IS NULL
       OR p_root_cause_id = ''
       OR p_root_cause_id LIKE '${%}'
    THEN
        RETURN;
    END IF;

    -- Query general_metric_metadata_results directly and expand JSON keys dynamically.
    -- This works for any root cause without needing a static per-RC view.
    -- jsonb_lower_keys normalises uppercase keys (Oracle/MSSQL convention) to lowercase.
    RETURN QUERY
    SELECT
        -- Lowercase keys, add server, strip null values so Grafana shows only populated columns
        (
            SELECT jsonb_object_agg(k, v)
            FROM jsonb_each(
                monitoring.jsonb_lower_keys(elem)
                || jsonb_build_object('server', r.server)
            ) t(k, v)
            WHERE v IS DISTINCT FROM 'null'::jsonb
        )::json AS result,
        r.entry_date
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    WHERE r.metric_name = p_root_cause_id;

EXCEPTION
    WHEN OTHERS THEN RETURN;
END;
$_$;

CREATE OR REPLACE FUNCTION monitoring.gmmr_maintain(p_keep_months integer DEFAULT 12, p_ahead_months integer DEFAULT 12) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ahead_to date := (date_trunc('month', now()) + make_interval(months => p_ahead_months))::date;
    cutoff   date := (date_trunc('month', now()) - make_interval(months => p_keep_months))::date;
    m      date;
    pname  text;
    r      record;
    lo     date;
    v_dedup bigint;
    v_logdel bigint;
BEGIN
    -- Ensure partitions exist from the current month through p_ahead_months ahead.
    m := date_trunc('month', now())::date;
    WHILE m <= ahead_to LOOP
        pname := format('gmmr_%s', to_char(m, 'YYYY_MM'));
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS monitoring.%I '
            'PARTITION OF monitoring.general_metric_metadata_results '
            'FOR VALUES FROM (%L) TO (%L)',
            pname, m, (m + interval '1 month')::date);
        m := (m + interval '1 month')::date;
    END LOOP;

    FOR r IN
        SELECT c.relname
        FROM pg_inherits i
        JOIN pg_class c     ON c.oid = i.inhrelid
        JOIN pg_class p     ON p.oid = i.inhparent
        JOIN pg_namespace n ON n.oid = p.relnamespace
        WHERE n.nspname = 'monitoring'
          AND p.relname = 'general_metric_metadata_results'
          AND c.relname ~ '^gmmr_[0-9]{4}_[0-9]{2}$'
    LOOP
        lo := to_date(substring(r.relname FROM 'gmmr_([0-9]{4}_[0-9]{2})'), 'YYYY_MM');
        IF lo < cutoff THEN
            EXECUTE format('DROP TABLE IF EXISTS monitoring.%I', r.relname);
            RAISE NOTICE 'gmmr: dropped old partition %', r.relname;
        END IF;
    END LOOP;

    -- Collapse duplicate snapshots: keep the newest row per
    -- (server, metric_name, identical metric_metadata); drop the older copies.
    -- (Folds in the former scripts/dedup_gmmr_metric_metadata.sql so the cleanup
    --  runs on the same maintenance schedule instead of by hand.)
    WITH ranked AS (
        SELECT entry_date, id,
               row_number() OVER (
                   PARTITION BY server, metric_name, md5(coalesce(metric_metadata::text, ''))
                   ORDER BY id DESC
               ) AS rn
        FROM monitoring.general_metric_metadata_results
    )
    DELETE FROM monitoring.general_metric_metadata_results g
    USING ranked r2
    WHERE g.entry_date = r2.entry_date AND g.id = r2.id AND r2.rn > 1;
    GET DIAGNOSTICS v_dedup = ROW_COUNT;
    RAISE NOTICE 'gmmr: deduped % duplicate metric_metadata rows', v_dedup;

    -- Retention: prune metrics.server_log beyond the keep window (same p_keep_months).
    -- Guarded so gmmr_maintain still works if server_log hasn't been created yet.
    IF to_regclass('metrics.server_log') IS NOT NULL THEN
        DELETE FROM metrics.server_log
        WHERE changed_at < (now() - make_interval(months => p_keep_months));
        GET DIAGNOSTICS v_logdel = ROW_COUNT;
        RAISE NOTICE 'gmmr: pruned % server_log rows older than % months', v_logdel, p_keep_months;
    END IF;
END $_$;

CREATE OR REPLACE FUNCTION monitoring.gmmr_upsert_latest() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO monitoring.metric_latest_result
        (server, metric_name, category_id, metric_config, metric_metadata, entry_date)
    VALUES (NEW.server, NEW.metric_name, NEW.category_id,
            NEW.metric_config, NEW.metric_metadata, NEW.entry_date)
    ON CONFLICT (server, metric_name) DO UPDATE SET
        category_id     = EXCLUDED.category_id,
        metric_config   = EXCLUDED.metric_config,
        metric_metadata = EXCLUDED.metric_metadata,
        entry_date      = EXCLUDED.entry_date
    WHERE EXCLUDED.entry_date >= monitoring.metric_latest_result.entry_date
       OR monitoring.metric_latest_result.entry_date IS NULL;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION monitoring.jsonb_lower_keys(data jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
    SELECT jsonb_object_agg(lower(key), value)
    FROM jsonb_each(data);
$$;

CREATE OR REPLACE PROCEDURE monitoring.sensitive_schema_column_enable(IN p_column_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF  p_column_name IS NOT NULL THEN
            UPDATE monitoring.schema
            SET is_enabled = not(is_enabled) where column_name = p_column_name;
            
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION monitoring.view_name_for_rc(p_rc text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT 'v_' || lower(regexp_replace(p_rc, '[^a-zA-Z0-9]+', '_', 'g'))
$$;

CREATE OR REPLACE PROCEDURE public.add_path(IN rc_id text, IN vslug text, IN path_name text, IN path_desc text, IN step1_name text, IN step1_sql text, IN step1_exp text, IN step2_name text, IN step2_sql text, IN step2_exp text)
    LANGUAGE plpgsql
    AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES (vslug, 'query', step1_name,
            jsonb_build_object('sql', step1_sql),
            step1_exp::jsonb)
    RETURNING id INTO ls1;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES (vslug, 'query', step2_name,
            jsonb_build_object('sql', step2_sql),
            step2_exp::jsonb)
    RETURNING id INTO ls2;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES (rc_id, vslug, path_name, path_desc, 'authored', true)
    RETURNING id INTO lp;

    INSERT INTO rootcause.detection_path_steps
      (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
      (lp, ls1, 1, 'next',      'ruled_out'),
      (lp, ls2, 2, 'confirmed', 'ruled_out');
END;
$$;

CREATE OR REPLACE FUNCTION public.execute_queries_and_update_counts() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_queries CURSOR FOR 
        SELECT row_id , label, query 
        FROM  widget.report_items_indicators
        WHERE query IS NOT NULL AND query != '' and row_id=1;
    
    rec RECORD;
    query_count INTEGER;
    dynamic_sql TEXT;
BEGIN
    -- Open cursor and loop through each query
    FOR rec IN cur_queries LOOP
        BEGIN
            -- Prepare the dynamic SQL
            dynamic_sql := rec.query;
            
            -- Execute the query and get the count
            EXECUTE dynamic_sql INTO query_count;
            
            -- Update the count field for this record
            UPDATE widget.report_items_indicators 
            SET label = label|| query_count::TEXT
            WHERE row_id = rec.id;
            
            -- Log successful execution (optional)
            RAISE NOTICE 'Query ID % executed successfully. Count: %', rec.id, query_count;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Handle errors gracefully
                UPDATE query_results 
                SET label = label|| '0' -- Use -1 to indicate error                 
                WHERE id = rec.id;
                
                RAISE NOTICE 'Error executing query ID %: %', rec.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Finished processing all queries';
END;
$$;

CREATE OR REPLACE FUNCTION public.get_local_ip_resolved() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    host text;
    ip text;
BEGIN
    SELECT setting INTO host
    FROM pg_settings
    WHERE name = 'listen_addresses';

    -- If multiple addresses, pick the first
    host := split_part(host, ',', 1);

    -- Resolve hostname to IP
    SELECT inet_server_addr() INTO ip;
    RETURN ip;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_local_ipv4() RETURNS inet
    LANGUAGE plpgsql
    AS $$
DECLARE
    ip inet;
BEGIN
    ip := inet_server_addr();
    
    -- If IPv6 loopback, try to convert or skip
    IF ip <<= '::1/128' THEN
        RETURN NULL;  -- optional: or return 127.0.0.1
    END IF;
    
    -- If IPv4, return
    IF ip <<= '0.0.0.0/0' THEN
        RETURN ip;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE PROCEDURE public.pg_who_is_active(IN show_sleeping boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT 
        pid,
        usename,
        datname,
        application_name app,
        client_addr,
        backend_start,
        query_start,
        EXTRACT(EPOCH FROM (now() - query_start))::INTEGER,
        state,
        wait_event IS NOT NULL,
        query
    FROM 
        pg_stat_activity
    WHERE 
        (state != 'idle' OR show_sleeping = true)
        AND pid != pg_backend_pid()
    ORDER BY 
        EXTRACT(EPOCH FROM (now() - query_start))::INTEGER DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_after_insert_active_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if this row matches any SQLi signature
    IF EXISTS (
        SELECT 1
        FROM NEW
		join config.sqli_signatures s on  NEW.query ~ s.pattern
        JOIN rootcause.v_root_causes_with_context rcc
          ON rcc.issue_id::text = s.issue_id::text
         AND rcc.root_cause_number = s.root_cause_number
        WHERE NEW.query ~ s.pattern
    ) THEN
        INSERT INTO monitoring.alerts_open (
            transaction_row_id,
            server,
            table_name,
            root_cause,
            issue_id,
            rootcause_number
        )
        SELECT
            NEW.row_id,
            NEW.server,
            'monitoring.active_transactions',
            rcc.root_cause,
            rcc.issue_id,
            rcc.root_cause_number
        FROM config.sqli_signatures s
        JOIN rootcause.v_root_causes_with_context rcc
          ON rcc.issue_id::text = s.issue_id::text
         AND rcc.root_cause_number = s.root_cause_number
        WHERE NEW.query ~ s.pattern;
    END IF;

    RETURN NEW;  -- REQUIRED for FOR EACH ROW
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_after_insert_update_active_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO monitoring.alerts_open (
        transaction_row_id,
        server,
		query , 
        table_name,
        root_cause,
        issue_id,
        rootcause_number
    )
    SELECT
        NEW.row_id,
        NEW.server,
		NEW.QUERY , 
        'monitoring.active_transactions',
        rcc.root_cause,
        rcc.issue_id,
        rcc.root_cause_number
    FROM config.sqli_signatures s
    JOIN rootcause.v_root_causes_with_context rcc
      ON rcc.issue_id::text = s.issue_id::text
     AND rcc.root_cause_number = s.root_cause_number
    WHERE NEW.query ~ s.pattern;

INSERT INTO monitoring.alerts_open (
        transaction_row_id,
        server,
        table_name,
        root_cause,
        issue_id,
        rootcause_number
    )

select 	row_id , 
		server , 
		'monitoring.active_transactions' , 
		root_cause , 
		'SEC-SQL-CFG-002' , 
		7 
from 		
	 monitoring.v_SEC_SQL_CFG_002 where last_request_end_time > now() - interval '1 hour';
	update monitoring.alerts_open set state = 'closed' where entry_date < Now() - interval '1 hour';
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_after_update_active_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if this row matches any SQLi signature
    IF EXISTS (
        SELECT 1
        FROM NEW
		join config.sqli_signatures s on  NEW.query ~ s.pattern
        JOIN rootcause.v_root_causes_with_context rcc
          ON rcc.issue_id::text = s.issue_id::text
         AND rcc.root_cause_number = s.root_cause_number
        WHERE NEW.query ~ s.pattern
    ) THEN
        INSERT INTO monitoring.alerts_open (
            transaction_row_id,
            server,
            table_name,
            root_cause,
            issue_id,
            rootcause_number
        )
        SELECT
            NEW.row_id,
            NEW.server,
            'monitoring.active_transactions',
            rcc.root_cause,
            rcc.issue_id,
            rcc.root_cause_number
        FROM config.sqli_signatures s
        JOIN rootcause.v_root_causes_with_context rcc
          ON rcc.issue_id::text = s.issue_id::text
         AND rcc.root_cause_number = s.root_cause_number
        WHERE NEW.query ~ s.pattern;
    END IF;

    RETURN NEW;  -- REQUIRED for FOR EACH ROW
END;
$$;

CREATE OR REPLACE FUNCTION public.update_uuid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.my_uuid_column := gen_random_uuid();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE PROCEDURE rootcause.add_detection_path(IN rc_id text, IN vslug text, IN path_name text, IN path_desc text, IN step1_name text, IN step1_sql text, IN step1_exp text, IN step2_name text, IN step2_sql text, IN step2_exp text)
    LANGUAGE plpgsql
    AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
  INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
  VALUES (vslug,'query',step1_name, jsonb_build_object('sql',step1_sql), step1_exp::jsonb)
  RETURNING id INTO ls1;
  INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
  VALUES (vslug,'query',step2_name, jsonb_build_object('sql',step2_sql), step2_exp::jsonb)
  RETURNING id INTO ls2;
  INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
  VALUES (rc_id, vslug, path_name, path_desc, 'authored', true)
  RETURNING id INTO lp;
  INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
  VALUES (lp,ls1,1,'next','ruled_out'),(lp,ls2,2,'confirmed','ruled_out');
END;
$$;

CREATE OR REPLACE PROCEDURE rootcause.add_resolution_path(IN rc_id text, IN vslug text, IN path_name text, IN path_slug text, IN path_desc text, IN path_risk text, IN s1_name text, IN s1_type text, IN s1_action text, IN s1_risk text, IN s1_rev boolean, IN s2_name text, IN s2_type text, IN s2_action text, IN s2_risk text, IN s2_rev boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
  INSERT INTO rootcause.resolution_steps
    (vendor_slug, step_type, name, content, risk_level, is_reversible)
  VALUES (vslug, s1_type, s1_name, jsonb_build_object('action', s1_action), s1_risk, s1_rev)
  ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content
  RETURNING id INTO ls1;

  INSERT INTO rootcause.resolution_steps
    (vendor_slug, step_type, name, content, risk_level, is_reversible)
  VALUES (vslug, s2_type, s2_name, jsonb_build_object('action', s2_action), s2_risk, s2_rev)
  ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content
  RETURNING id INTO ls2;

  INSERT INTO rootcause.resolution_paths
    (root_cause_id, vendor_slug, name, slug, description,
     risk_level, execution_mode, status, is_active)
  VALUES (rc_id, vslug, path_name, path_slug, path_desc,
          path_risk, 'supervised', 'authored', true)
  ON CONFLICT (root_cause_id, vendor_slug, name)
  DO UPDATE SET description = EXCLUDED.description
  RETURNING id INTO lp;

  INSERT INTO rootcause.resolution_path_steps
    (resolution_path_id, resolution_step_id, step_order, on_success, on_failure)
  VALUES
    (lp, ls1, 1, 'next',     'stop'),
    (lp, ls2, 2, 'complete', 'stop')
  ON CONFLICT (resolution_path_id, step_order) DO NOTHING;
END;
$$;

CREATE OR REPLACE PROCEDURE rootcause.delete_risk_level(IN p_row_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM rootcause.risk_level WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'risk_level row_id % not found', p_row_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE rootcause.save_risk_level(INOUT p_row_id integer, IN p_risk_level character varying, IN p_is_active boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_risk_level IS NULL OR length(trim(p_risk_level)) = 0 THEN
        RAISE EXCEPTION 'risk_level cannot be empty';
    END IF;

    IF p_row_id IS NULL THEN
        -- Prevent duplicate active labels (case-insensitive, trimmed)
        IF EXISTS (
            SELECT 1 FROM rootcause.risk_level
             WHERE lower(trim(risk_level)) = lower(trim(p_risk_level))
        ) THEN
            RAISE EXCEPTION 'risk_level "%" already exists', p_risk_level;
        END IF;

        INSERT INTO rootcause.risk_level (risk_level, is_active)
        VALUES (trim(p_risk_level), COALESCE(p_is_active, true))
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE rootcause.risk_level
           SET risk_level = trim(p_risk_level),
               is_active  = COALESCE(p_is_active, is_active)
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'risk_level row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE rootcause.update_root_cause_result(IN p_root_cause_id text, IN p_server text)
    LANGUAGE plpgsql
    AS $$
BEGIN

    DELETE FROM rootcause.rootcause_alert_query_result_server
    WHERE server = p_server
      AND root_cause_id = p_root_cause_id;

    INSERT INTO rootcause.rootcause_alert_query_result_server
        (root_cause_id, server, query_result)
    SELECT
        p_root_cause_id,
        p_server,
        (select flowchart.execute_numeric_query(query))
    FROM rootcause.rootcause_alert_query
    WHERE root_cause_id = p_root_cause_id;

END;
$$;

CREATE OR REPLACE PROCEDURE siem_config.update_siem_config(IN p_siem_vendor character varying, IN p_siem_url character varying, IN p_siem_api_key character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN	    
	  if not exists  (select 1  from siem_config.sime_interface where siem_vendor = p_siem_vendor)	THEN  	
        INSERT INTO siem_config.sime_interface ( siem_vendor, siem_url, api_key )
		select p_siem_vendor, p_siem_url , p_siem_api_key;
		else 
			update siem_config.sime_interface set  siem_url = p_siem_url  , api_key = p_api_key 
			where siem_vendor = p_siem_vendor;
	end if;
END;
$$;

CREATE OR REPLACE PROCEDURE users.cleanup_temp_login_results()
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM users.temp_login_result 
    WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '1 hour');
END;
$$;

CREATE OR REPLACE FUNCTION users.hash_password_bcrypt(plain_password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- This creates a bcrypt hash compatible with Python's passlib
    -- Note: You might need to install additional extensions for bcrypt support
    -- For now, we'll use crypt with blowfish algorithm
    RETURN public.crypt(plain_password, public.gen_salt('bf'));
END;
$$;

CREATE OR REPLACE PROCEDURE users.upsert_user_with_hash(IN p_username character varying, IN p_first_name character varying, IN p_last_name character varying, IN p_email character varying, IN p_position character varying, IN p_plain_password character varying, IN p_is_superuser boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_hashed_password VARCHAR(255);
BEGIN
    -- Hash the password
    v_hashed_password := users.hash_password_bcrypt(p_plain_password);
    
    -- Insert or update user
    INSERT INTO users.user_panel (
        username,
        fname,
        lname,
        email,
        position,
        password_hash,
        is_superuser
    ) VALUES (
        p_username,
        p_first_name,
        p_last_name,
        p_email,
        p_position,
        v_hashed_password,
        p_is_superuser
    )
    ON CONFLICT (username) 
    DO UPDATE SET
        fname = EXCLUDED.fname,
        lname = EXCLUDED.lname,
        email = EXCLUDED.email,
        position = EXCLUDED.position,
        password_hash = EXCLUDED.password_hash,
        is_superuser = EXCLUDED.is_superuser,
        updated_at = CURRENT_TIMESTAMP;
END;
$$;

CREATE OR REPLACE PROCEDURE users.upsert_users(IN p_username character varying, IN p_fname character varying, IN p_lname character varying, IN p_password character varying, IN p_is_super boolean, IN p_email text, IN p_position text, IN p_add_modify_delete character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_add_modify_delete != 'delete' and not exists(select 1 from users.user_panel where username = p_username)THEN begin
        INSERT INTO users.user_panel (
            username, fname, lname,  email , user_position , is_super
        )
        VALUES (p_username, p_fname, p_lname, p_email ,p_position ,  p_is_super );
      	 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = p_username) THEN
    			EXECUTE format('CREATE USER %I WITH PASSWORD %L', p_username, p_password);				
  		END IF;

  		-- Grant connect
  		EXECUTE format('GRANT CONNECT ON DATABASE dbdome TO %I', p_username);
		EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA monitoring TO %I', p_username);
		EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA metrics TO %I', p_username);
	end;	  
    ELSE begin
        DELETE FROM users.user_panel  WHERE username = p_username;
		--EXECUTE format('DROP USER IF EXISTS %I', p_username);
		--EXECUTE format('REVOKE ALL PRIVILEGES ON DATABASE dbdome FROM %I', p_username);			
	end;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE users.validate_user_login(IN p_username character varying, IN p_password character varying, OUT p_is_valid boolean, OUT p_user_id integer, OUT p_first_name character varying, OUT p_last_name character varying, OUT p_email character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_stored_hash VARCHAR(255);
    v_user_record RECORD;
    v_session_id VARCHAR(255) := p_username; -- Using username as session_id for simplicity
BEGIN
    -- Initialize output parameters
    p_is_valid := FALSE;
    p_user_id := NULL;
    p_first_name := NULL;
    p_last_name := NULL;
    p_email := NULL;
    
    -- Clear any existing temp results for this session
    DELETE FROM users.temp_login_result WHERE session_id = v_session_id;
    
    -- Get user information and password hash
    SELECT 
        user_id,
        first_name,
        last_name,
        email,
        password_hash,
        is_superuser,
        last_login
    INTO v_user_record
    FROM users.user_panel
    WHERE username = p_username 
    AND is_active = TRUE;
    
    -- Check if user exists
    IF FOUND THEN
        -- Verify password using crypt function
        -- Note: This assumes passwords are hashed with crypt() function
        -- If you're using bcrypt from Python, you may need to adjust this
        IF crypt(p_password, v_user_record.password_hash) = v_user_record.password_hash THEN
            -- Password is correct
            p_is_valid := TRUE;
            p_user_id := v_user_record.user_id;
            p_first_name := v_user_record.first_name;
            p_last_name := v_user_record.last_name;
            p_email := v_user_record.email;
            
            -- Update last login time
            UPDATE users.user_panel
            SET last_login = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = v_user_record.user_id;
            
            -- Insert successful result into temp table
            INSERT INTO users.temp_login_result (
                session_id,
                is_valid,
                user_id,
                fname,
                lname,
                email,
                is_superuser,
                last_login
            ) VALUES (
                v_session_id,
                TRUE,
                v_user_record.user_id,
                v_user_record.first_name,
                v_user_record.last_name,
                v_user_record.email,
                v_user_record.is_superuser,
                CURRENT_TIMESTAMP
            );
        ELSE
            -- Password is incorrect
            INSERT INTO users.temp_login_result (
                session_id,
                is_valid,
                user_id,
                first_name,
                last_name,
                email,
                is_superuser,
                last_login
            ) VALUES (
                v_session_id,
                FALSE,
                NULL,
                NULL,
                NULL,
                NULL,
                FALSE,
                NULL
            );
        END IF;
    ELSE
        -- User not found
        INSERT INTO users.temp_login_result (
            session_id,
            is_valid,
            user_id,
            first_name,
            last_name,
            email,
            is_superuser,
            last_login
        ) VALUES (
            v_session_id,
            FALSE,
            NULL,
            NULL,
            NULL,
            NULL,
            FALSE,
            NULL
        );
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any errors
        p_is_valid := FALSE;
        p_user_id := NULL;
        p_first_name := NULL;
        p_last_name := NULL;
        p_email := NULL;
        
        -- Insert error result
        INSERT INTO users.temp_login_result (
            session_id,
            is_valid,
            user_id,
            first_name,
            last_name,
            email,
            is_superuser,
            last_login
        ) VALUES (
            v_session_id,
            FALSE,
            NULL,
            NULL,
            NULL,
            NULL,
            FALSE,
            NULL
        );
        
        -- Log the error (you might want to use your logging system here)
        RAISE NOTICE 'Login validation error: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE widget.customized_report_delete(IN p_report_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if  exists (SELECT 1 FROM widget.treeview where LOWER(item_name) = LOWER(p_report_name) ) THEN
		delete from  widget.treeview where LOWER(item_name) = LOWER(p_report_name) ;
		
	end if;
END;
$$;

CREATE OR REPLACE PROCEDURE widget.customized_report_delete(IN p_report_name text, IN p_update_type integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if  exists (SELECT 1 FROM widget.treeview where LOWER(item_name) = LOWER(p_report_name) ) and p_update_type = 1 THEN
		delete from  widget.treeview where LOWER(item_name) = LOWER(p_report_name) ;
		
	end if;
END;
$$;

CREATE OR REPLACE PROCEDURE widget.upsert_customized_report(IN p_report_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if not exists (SELECT 1 FROM widget.treeview where LOWER(item_name) = LOWER(p_report_name) ) THEN
		insert into widget.treeview (parent_row_id , item_name , level , report_url , is_active , item_sequence )
		select 0 , p_report_name , 2 , '/dbdome/items/'||p_report_name , true , '4.1.1';	
	end if;
END;
$$;

CREATE OR REPLACE VIEW config.v_blocked_ips_active AS
 SELECT block_id,
    (ip_address)::text AS ip_address,
    reason,
    blocked_by,
    blocked_at,
    expires_at,
        CASE
            WHEN (expires_at IS NULL) THEN 'Permanent'::text
            ELSE ((EXTRACT(epoch FROM (expires_at - now())))::integer || 's remaining'::text)
        END AS remaining
   FROM config.blocked_ips
  WHERE ((is_active = true) AND ((expires_at IS NULL) OR (expires_at > now())))
  ORDER BY blocked_at DESC;

CREATE OR REPLACE VIEW config.v_mail_alert_schedule AS
 SELECT m_mr.row_id AS metric_result_row_id,
    m_mr.server,
    m_mr.transaction_type,
    m_mr.metric_name,
    c_ma.body,
    c_ma.recipients,
    c_ma.report_password,
    c_ma.report_user,
    c_ma.report_url,
    c_ma.subject,
    m_c.smtp_server,
    m_c.smtp_password,
    m_c.smtp_user,
    m_c.smtp_port,
    m_c.tls,
    c_mas.interval_secs,
    c_mas.start_time,
    c_mas.end_time,
    (COALESCE((mail_alert_log.entry_date)::timestamp with time zone, (now() - '1 day'::interval)) + (((c_mas.interval_secs)::text || ' seconds'::text))::interval) AS next_time
   FROM ((((monitoring.metric_results m_mr
     JOIN config.mail_alerts c_ma ON (((c_ma.transaction_type)::text = (m_mr.transaction_type)::text)))
     JOIN config.mail_config m_c ON ((m_c.row_id = c_ma.mail_config_id)))
     JOIN config.mail_alerts_schedule c_mas ON ((c_mas.mail_alert_id = c_ma.mail_config_id)))
     LEFT JOIN ( SELECT max(mail_alert_log_1.entry_date) AS entry_date,
            mail_alert_log_1.metric_result_row_id
           FROM alerts.mail_alert_log mail_alert_log_1
          GROUP BY mail_alert_log_1.metric_result_row_id) mail_alert_log ON ((mail_alert_log.metric_result_row_id = m_mr.row_id)))
  WHERE (((COALESCE((mail_alert_log.entry_date)::timestamp with time zone, (now() - '1 day'::interval)) + (((c_mas.interval_secs)::text || ' seconds'::text))::interval) < now()) AND (((COALESCE((mail_alert_log.entry_date)::timestamp with time zone, (now() - '1 day'::interval)))::time without time zone >= c_mas.start_time) AND ((COALESCE((mail_alert_log.entry_date)::timestamp with time zone, (now() - '1 day'::interval)))::time without time zone <= c_mas.end_time)));

CREATE OR REPLACE VIEW config.v_masking_coverage AS
 SELECT server_name,
    regulation,
    count(*) AS total_sensitive_columns,
    sum(
        CASE
            WHEN is_active THEN 1
            ELSE 0
        END) AS actively_masked,
    array_agg(DISTINCT pii_type ORDER BY pii_type) AS pii_types_covered
   FROM config.masking_rules
  GROUP BY server_name, regulation
  ORDER BY server_name, regulation;

CREATE OR REPLACE VIEW config.v_masking_rules_detail AS
 SELECT server_name,
    database_name,
    table_name,
    column_name,
    pii_type,
    mask_type,
    allowed_roles,
    regulation,
    is_active,
    updated_at
   FROM config.masking_rules mr
  ORDER BY server_name, table_name, column_name;

CREATE OR REPLACE VIEW config.v_suspended_users_active AS
 SELECT suspension_id,
    server_name,
    login_name,
    reason,
    suspended_by,
    suspended_at,
    expires_at,
        CASE
            WHEN (expires_at IS NULL) THEN 'Permanent'::text
            ELSE ((EXTRACT(epoch FROM (expires_at - now())))::integer || 's remaining'::text)
        END AS remaining
   FROM config.suspended_users
  WHERE ((is_active = true) AND ((expires_at IS NULL) OR (expires_at > now())))
  ORDER BY suspended_at DESC;

CREATE OR REPLACE VIEW config.v_unmasked_sensitive_columns AS
 SELECT ss.server,
    ss.database_name,
    ss.table_name,
    ss.column_name,
    ss.pii_type,
    ss.data_type
   FROM (monitoring.sensitive_schema ss
     LEFT JOIN config.masking_rules mr ON ((((mr.server_name)::text = (ss.server)::text) AND ((mr.table_name)::text = (ss.table_name)::text) AND ((mr.column_name)::text = (ss.column_name)::text) AND (mr.is_active = true))))
  WHERE (mr.rule_id IS NULL)
  ORDER BY ss.server, ss.table_name;

CREATE OR REPLACE VIEW flowchart.v_sources_alerts AS
 SELECT o.row_id AS id,
    o.source_object AS source,
    o.target_object AS target,
    ( SELECT flowchart.execute_numeric_query(o.mainstat_query) AS execute_numeric_query) AS mainstat,
    now() AS last_seen,
    ( SELECT flowchart.color_by_threshold(o.mainstat_query, o.mainstat_threshold_id) AS color_by_threshold) AS color,
    o.alert_report,
    o.alert_mail,
    o.alert_siem
   FROM flowchart.visual_objects o
UNION ALL
 SELECT servers.row_id AS id,
    servers.db_vendor AS source,
    servers.servername AS target,
        CASE servers.is_active
            WHEN true THEN 1
            ELSE 0
        END AS mainstat,
    now() AS last_seen,
        CASE
            WHEN (servers.is_active IS TRUE) THEN 'green'::text
            ELSE 'red'::text
        END AS color,
    false AS alert_report,
    false AS alert_mail,
    false AS alert_siem
   FROM metrics.servers
UNION ALL
 SELECT servers.row_id AS id,
    servers.servername AS source,
    'Data sources'::text AS target,
        CASE servers.is_active
            WHEN true THEN 1
            ELSE 0
        END AS mainstat,
    now() AS last_seen,
        CASE
            WHEN (servers.is_active IS TRUE) THEN 'green'::text
            ELSE 'red'::text
        END AS color,
    false AS alert_report,
    false AS alert_mail,
    false AS alert_siem
   FROM metrics.servers;

CREATE OR REPLACE VIEW log.v_active_threats AS
 SELECT incident_id,
    title,
    severity,
    regulation,
    server_name,
    db_user,
    client_ip,
    status,
    created_at
   FROM log.security_incidents i
  WHERE ((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('ACKNOWLEDGED'::character varying)::text]))
  ORDER BY
        CASE severity
            WHEN 'CRITICAL'::text THEN 1
            WHEN 'HIGH'::text THEN 2
            WHEN 'MEDIUM'::text THEN 3
            ELSE 4
        END, created_at DESC;

CREATE OR REPLACE VIEW log.v_attestation_summary AS
 SELECT ap.period_id,
    ap.period_name,
    ap.regulation,
    ap.period_start,
    ap.period_end,
    ap.due_date,
    ap.status AS period_status,
    count(*) AS total_controls,
    count(*) FILTER (WHERE ((a.attestation_status)::text = 'ATTESTED'::text)) AS attested,
    count(*) FILTER (WHERE ((a.attestation_status)::text = 'EXCEPTION'::text)) AS exceptions,
    count(*) FILTER (WHERE ((a.attestation_status)::text = 'NOT_APPLICABLE'::text)) AS not_applicable,
    count(*) FILTER (WHERE ((a.attestation_status)::text = 'PENDING'::text)) AS pending,
    round(((100.0 * (count(*) FILTER (WHERE ((a.attestation_status)::text <> 'PENDING'::text)))::numeric) / (NULLIF(count(*), 0))::numeric), 1) AS completion_pct
   FROM (config.attestation_periods ap
     LEFT JOIN log.attestations a ON ((a.period_id = ap.period_id)))
  GROUP BY ap.period_id, ap.period_name, ap.regulation, ap.period_start, ap.period_end, ap.due_date, ap.status
  ORDER BY ap.period_end DESC, ap.regulation;

CREATE OR REPLACE VIEW log.v_blocked_events AS
 SELECT audit_id,
    event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 500) AS sql_preview,
    matched_policy,
    regulation,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((action_taken)::text = 'BLOCKED'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_cross_border_summary AS
 SELECT destination_server,
    destination_country,
    transfer_mechanism,
    has_legal_basis,
    risk_level,
    count(*) AS transfer_count,
    max(detected_at) AS last_detected,
    min(detected_at) AS first_detected
   FROM log.cross_border_transfers
  GROUP BY destination_server, destination_country, transfer_mechanism, has_legal_basis, risk_level
  ORDER BY has_legal_basis, risk_level DESC, (max(detected_at)) DESC;

CREATE OR REPLACE VIEW log.v_ddl_audit_daily_summary AS
 SELECT date(event_time) AS report_date,
    server_name,
    ddl_command,
    object_type,
    count(*) AS event_count,
    count(DISTINCT db_user) AS unique_users
   FROM log.ddl_audit_log
  GROUP BY (date(event_time)), server_name, ddl_command, object_type
  ORDER BY (date(event_time)) DESC, (count(*)) DESC;

CREATE OR REPLACE VIEW log.v_ddl_high_risk AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    object_schema,
    object_name,
    ddl_command,
    risk_level,
    regulation
   FROM log.ddl_audit_log
  WHERE (((ddl_command)::text = ANY (ARRAY[('DROP'::character varying)::text, ('TRUNCATE'::character varying)::text])) OR ((risk_level)::text = ANY (ARRAY[('HIGH'::character varying)::text, ('CRITICAL'::character varying)::text])))
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_gdpr_audit AS
 SELECT audit_id,
    event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 500) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'GDPR'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_hipaa_audit AS
 SELECT audit_id,
    event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 500) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'HIPAA'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_pci_dss_audit AS
 SELECT audit_id,
    event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 500) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'PCI-DSS'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_response_activity_24h AS
 SELECT date_trunc('hour'::text, triggered_at) AS hour,
    response_type,
    count(*) AS response_count,
    sum(
        CASE
            WHEN success THEN 1
            ELSE 0
        END) AS successes,
    sum(
        CASE
            WHEN (NOT success) THEN 1
            ELSE 0
        END) AS failures
   FROM log.threat_response_log
  WHERE (triggered_at >= (now() - '24:00:00'::interval))
  GROUP BY (date_trunc('hour'::text, triggered_at)), response_type
  ORDER BY (date_trunc('hour'::text, triggered_at)) DESC, response_type;

CREATE OR REPLACE VIEW log.v_rpt_gdpr_ddl_blocked AS
 SELECT event_time,
    server_name,
    db_user,
    client_ip,
    "left"(sql_statement, 400) AS sql_preview,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = 'GDPR'::text) AND ((action_taken)::text = 'BLOCKED'::text) AND (sql_statement ~* '^\s*(DROP|ALTER|TRUNCATE)\s+'::text))
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_gdpr_high_risk AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 300) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = 'GDPR'::text) AND (risk_score >= 70))
  ORDER BY risk_score DESC, event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_gdpr_processing_log AS
 SELECT date(event_time) AS activity_date,
    server_name,
    db_name,
    db_user,
    action_taken,
    count(*) AS access_count,
    max(risk_score) AS max_risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'GDPR'::text)
  GROUP BY (date(event_time)), server_name, db_name, db_user, action_taken
  ORDER BY (date(event_time)) DESC, (count(*)) DESC;

CREATE OR REPLACE VIEW log.v_rpt_hipaa_afterhours AS
 SELECT event_time,
    server_name,
    db_user,
    client_ip,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = 'HIPAA'::text) AND ((action_taken)::text = 'BLOCKED'::text) AND ((EXTRACT(hour FROM (event_time AT TIME ZONE 'localtime'::text)) >= (0)::numeric) AND (EXTRACT(hour FROM (event_time AT TIME ZONE 'localtime'::text)) <= (5)::numeric)))
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_hipaa_phi_access AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 300) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'HIPAA'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_hipaa_user_access_freq AS
 SELECT db_user,
    server_name,
    count(*) AS total_accesses,
    sum(
        CASE
            WHEN ((action_taken)::text = 'BLOCKED'::text) THEN 1
            ELSE 0
        END) AS blocked,
    max(risk_score) AS max_risk,
    min(event_time) AS first_access,
    max(event_time) AS last_access
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'HIPAA'::text)
  GROUP BY db_user, server_name
  ORDER BY (count(*)) DESC;

CREATE OR REPLACE VIEW log.v_rpt_pcidss_blocked AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 300) AS sql_preview,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = 'PCI-DSS'::text) AND ((action_taken)::text = 'BLOCKED'::text))
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_pcidss_daily_summary AS
 SELECT date(event_time) AS report_date,
    action_taken,
    count(*) AS event_count,
    count(DISTINCT db_user) AS unique_users,
    count(DISTINCT server_name) AS servers_affected,
    max(risk_score) AS max_risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'PCI-DSS'::text)
  GROUP BY (date(event_time)), action_taken
  ORDER BY (date(event_time)) DESC, (count(*)) DESC;

CREATE OR REPLACE VIEW log.v_rpt_pcidss_privileged_access AS
 SELECT event_time,
    server_name,
    db_user,
    client_ip,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = ANY (ARRAY[('PCI-DSS'::character varying)::text, ('SOC2'::character varying)::text])) AND ((action_taken)::text = ANY (ARRAY[('ALERTED'::character varying)::text, ('BLOCKED'::character varying)::text])))
  ORDER BY risk_score DESC, event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_pcidss_sqli AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    "left"(sql_statement, 400) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE (((regulation)::text = 'PCI-DSS'::text) AND (sql_statement ~* 'UNION|SELECT.*FROM.*WHERE|xp_cmdshell|INTO OUTFILE|SLEEP\(|BENCHMARK\('::text))
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_soc2_high_risk_users AS
 SELECT event_time,
    server_name,
    db_user,
    risk_score,
    risk_factors,
    active_sessions,
    active_queries
   FROM monitoring.user_risk_events e
  WHERE (risk_score >= 70)
  ORDER BY risk_score DESC, event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_soc2_logical_access AS
 SELECT event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'SOC2'::text)
  ORDER BY risk_score DESC, event_time DESC;

CREATE OR REPLACE VIEW log.v_rpt_soc2_policy_violations AS
 SELECT fp.policy_name,
    fp.severity,
    fp.regulation,
    count(al.audit_id) AS violation_count,
    count(DISTINCT al.db_user) AS unique_users,
    count(DISTINCT al.server_name) AS servers,
    max(al.event_time) AS last_seen
   FROM (log.firewall_audit_log al
     JOIN config.firewall_policies fp ON ((fp.policy_id = al.matched_policy)))
  WHERE ((al.action_taken)::text = ANY (ARRAY[('BLOCKED'::character varying)::text, ('ALERTED'::character varying)::text]))
  GROUP BY fp.policy_name, fp.severity, fp.regulation
  ORDER BY (count(al.audit_id)) DESC;

CREATE OR REPLACE VIEW log.v_rpt_soc2_privileged_users AS
 SELECT db_user,
    server_name,
    count(*) AS total_events,
    sum(
        CASE
            WHEN ((action_taken)::text = 'BLOCKED'::text) THEN 1
            ELSE 0
        END) AS blocked_count,
    max(risk_score) AS max_risk,
    max(event_time) AS last_activity
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'SOC2'::text)
  GROUP BY db_user, server_name
  ORDER BY (count(*)) DESC;

CREATE OR REPLACE VIEW log.v_soc2_audit AS
 SELECT audit_id,
    event_time,
    server_name,
    vendor,
    db_user,
    client_ip,
    db_name,
    "left"(sql_statement, 500) AS sql_preview,
    action_taken,
    risk_score
   FROM log.firewall_audit_log
  WHERE ((regulation)::text = 'SOC2'::text)
  ORDER BY event_time DESC;

CREATE OR REPLACE VIEW meta.v_schema_migrations_latest AS
 SELECT DISTINCT ON (filename) filename,
    checksum,
    applied_at,
    execution_ms,
    success,
    error,
        CASE
            WHEN success THEN 'ok'::text
            ELSE 'failed'::text
        END AS status
   FROM meta.schema_migrations
  ORDER BY filename, applied_at DESC;

CREATE OR REPLACE VIEW rootcause.v_rootcauses AS
 SELECT DISTINCT d.code AS domain_code,
    d.name AS domain_name,
    a.code AS area_code,
    a.name AS area_name,
    i.name AS issue_name,
    stps.parameters,
    i.issue_id,
    rc.root_cause_id,
    rc.name AS root_cause_name,
    rc.description AS root_cause_desc,
    dp.name AS detection_name,
    dp.description AS detection_desc,
    stps.name AS step_name,
    stps.name,
    stps.content,
    stps.expected,
    dp.is_active,
    v.slug AS vendor_name,
    rpst.risk_level
   FROM (((((((((((rootcause.issues i
     JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
     JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
     JOIN rootcause.root_causes rc ON (((rc.issue_id)::text = (i.issue_id)::text)))
     JOIN rootcause.detection_paths dp ON (((dp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.detection_path_steps stpstp ON ((stpstp.detection_path_id = dp.id)))
     JOIN rootcause.detection_steps stps ON ((stps.id = stpstp.detection_step_id)))
     JOIN rootcause.vendors v ON (((v.slug)::text = (stps.vendor_slug)::text)))
     JOIN rootcause.resolution_paths rp ON (((rp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.resolution_path_steps rpstp ON ((rpstp.resolution_path_id = rp.id)))
     JOIN rootcause.resolution_steps rpst ON ((rpst.id = rpstp.resolution_step_id)))
     JOIN rootcause.risk_level rl ON ((rl.risk_level = (rp.risk_level)::bpchar)))
  WHERE ((d.is_enabled IS TRUE) AND (a.is_enabled IS TRUE));

CREATE OR REPLACE VIEW metrics.v_custom_metrics AS
 SELECT custom_metrics.query,
    custom_metrics.category_id,
    custom_metrics.metric_name,
    custom_metrics.is_active,
    custom_metrics.db_vendor
   FROM metrics.custom_metrics
UNION ALL
 SELECT replace((v_rootcauses.content ->> 'sql'::text), '\n'::text, ' '::text) AS query,
    '-1'::integer AS category_id,
    v_rootcauses.root_cause_id AS metric_name,
    v_rootcauses.is_active,
    v_rootcauses.vendor_name AS db_vendor
   FROM rootcause.v_rootcauses;

CREATE OR REPLACE VIEW metrics.v_servers_processes AS
 SELECT s.row_id,
    s.server,
    s.servername,
    s.database,
    s.username,
    s.password,
    s.driver,
    s.is_active,
    s.db_vendor,
    pr.row_id AS process_id
   FROM (metrics.servers s
     JOIN processes.process pr ON ((pr.server_id = s.row_id)));

CREATE OR REPLACE VIEW metrics.v_servers_routines AS
 SELECT s.row_id,
    s.server,
    s.servername,
    s.database,
    s.username,
    s.password,
    s.driver,
    s.is_active,
    r.routine_name
   FROM ((metrics.servers s
     JOIN metrics.servers_routines sr ON ((sr.server_id = s.row_id)))
     JOIN metrics.routines r ON ((r.row_id = sr.routine_id)))
  WHERE ((s.is_active = true) AND (r.is_active = true));

CREATE OR REPLACE VIEW metrics.v_servers_routines_active AS
 SELECT s.row_id,
    s.server,
    s.servername,
    s.database,
    s.username,
    s.password,
    s.driver,
    s.is_active,
    r.routine_name,
    js.job_id,
    js.duration_secs,
    js.next_run_time,
    s.port,
    s.dsn,
    s.auth_type,
    s.service_name,
    s.server_id
   FROM ((((metrics.servers s
     JOIN metrics.servers_routines sr ON ((sr.server_id = s.row_id)))
     JOIN metrics.routines r ON ((r.row_id = sr.routine_id)))
     JOIN jobs.monitoring_jobschdules js ON ((js.row_id = sr.scheduler_id)))
     JOIN jobs.monitoring_jobs j ON ((j.row_id = js.job_id)))
  WHERE ((s.is_active = true) AND (r.is_active = true) AND ((js.next_run_time + (((js.duration_secs)::text || ' seconds'::text))::interval) < now()));

CREATE OR REPLACE VIEW monitoring.connection_count AS
 SELECT server,
    login_name,
    connection_count,
    entry_date
   FROM ( SELECT unnamed_subquery_1.server,
            unnamed_subquery_1.login_name,
            unnamed_subquery_1.connection_count,
            unnamed_subquery_1.entry_date,
            row_number() OVER (PARTITION BY unnamed_subquery_1.login_name ORDER BY unnamed_subquery_1.entry_date DESC) AS seq
           FROM ( SELECT (j.value ->> 'login_name'::text) AS login_name,
                    (j.value ->> 'connection_count'::text) AS connection_count,
                    r.server,
                    r.entry_date
                   FROM (monitoring.general_metric_metadata_results_old r
                     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
                  WHERE ((r.metric_name)::text = 'Connection count per user'::text)) unnamed_subquery_1
          WHERE (unnamed_subquery_1.login_name <> 'infosecuser'::text)) unnamed_subquery
  WHERE (seq = 1);

CREATE OR REPLACE VIEW monitoring.expensive_queries AS
 SELECT r.row_id,
    r.server,
    (j.value ->> 'Total_Logical_Reads'::text) AS total_logical_reads,
    (j.value ->> 'Total_Worker_Time'::text) AS total_worker_time,
    (j.value ->> 'Avg_Worker_Time'::text) AS avg_worker_time,
    (j.value ->> 'Total_Elapsed_Time'::text) AS total_elapsed_time,
    (j.value ->> 'Avg_Elapsed_Time'::text) AS avg_elapsed_time,
    (j.value ->> 'Creation_Time'::text) AS creation_time,
    (j.value ->> 'Query'::text) AS query,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'mssql_expensive_queries'::text) AND (r.server IS NOT NULL) AND (r.entry_date > (now() - '00:15:00'::interval)));

CREATE OR REPLACE VIEW monitoring.linked_servers_hidden_credentials AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'product'::text) AS product,
    (j.value ->> 'provider'::text) AS provider,
    (j.value ->> 'data_source'::text) AS data_source,
    (j.value ->> 'is_linked'::text) AS is_linked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Linked servers hidden credentials'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Linked servers hidden credentials'::text))));

CREATE OR REPLACE VIEW monitoring.v_schema AS
 SELECT data_type,
    table_name,
    column_name,
    table_catalog,
    entry_date
   FROM ( SELECT row_number() OVER (PARTITION BY unnamed_subquery_1.table_name, unnamed_subquery_1.column_name, unnamed_subquery_1.table_catalog ORDER BY unnamed_subquery_1.entry_date DESC) AS seq,
            unnamed_subquery_1.data_type,
            unnamed_subquery_1.table_name,
            unnamed_subquery_1.column_name,
            unnamed_subquery_1.table_catalog,
            unnamed_subquery_1.entry_date
           FROM ( SELECT unnamed_subquery_2.data_type,
                    unnamed_subquery_2.table_name,
                    unnamed_subquery_2.column_name,
                    unnamed_subquery_2.table_catalog,
                    unnamed_subquery_2.entry_date
                   FROM ( SELECT r.server,
                            (j.value ->> 'DATA_TYPE'::text) AS data_type,
                            (j.value ->> 'TABLE_NAME'::text) AS table_name,
                            (j.value ->> 'COLUMN_NAME'::text) AS column_name,
                            (j.value ->> 'TABLE_CATALOG'::text) AS table_catalog,
                            r.entry_date
                           FROM (monitoring.general_metric_metadata_results_old r
                             CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
                          WHERE ((r.metric_name)::text = 'mssql_schema'::text)) unnamed_subquery_2) unnamed_subquery_1) unnamed_subquery
  WHERE (seq = 1);

CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring.sensitive_columns AS
 SELECT DISTINCT column_name
   FROM monitoring.v_schema
  WHERE (column_name ~~* ANY (ARRAY['%fname%'::text, '%lname%'::text, '%email%'::text, '%lastname%'::text, '%firstname%'::text, '%last_name%'::text, '%phone%'::text, '%ssn%'::text, '%dob%'::text, '%birth%'::text, '%credit%'::text, '%idcard%'::text, '%idnum%'::text, '%id_card%'::text, '%id_num%'::text]))
  WITH NO DATA;

CREATE OR REPLACE VIEW monitoring.v_active_connections AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Active connections'::text);

CREATE OR REPLACE VIEW monitoring.v_active_transactions AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'session_id'::text) AS session_id,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 1000.0))::double precision) AS start_time,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'total_elapsed_time'::text) AS total_elapsed_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    (j.value ->> 'query_text'::text) AS query,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Active transactions'::text);

CREATE OR REPLACE VIEW monitoring.v_blocking_sessions AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'wait_resource'::text) AS wait_resource,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Blocking sessions'::text);

CREATE OR REPLACE VIEW monitoring.v_blocking_transactions AS
 SELECT r.row_id,
    r.server,
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
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'long_block_transactions'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'long_block_transactions'::text))));

CREATE OR REPLACE VIEW monitoring.v_expensive_queries AS
 SELECT r.server,
    r.row_id,
    to_timestamp((((((j.value ->> 'Creation Time'::text))::bigint)::numeric / 1000.0))::double precision) AS last_request_end_time,
    (j.value ->> 'Complete Query Text'::text) AS query,
    ((j.value ->> 'Total Elapsed Time (ms)'::text))::numeric AS duration,
    ((j.value ->> 'Avg Elapsed Time (ms)'::text))::numeric AS avg_duration,
    ((j.value ->> 'Avg Logical Reads (MB)'::text))::numeric AS avg_logical_reads,
    ((j.value ->> 'Total Worker Time (ms)'::text))::numeric AS total_worker_time,
    ((j.value ->> 'Total Elapsed Time (ms)'::text))::numeric AS total_elapsed_time,
    ((j.value ->> 'Total Logical Reads (MB)'::text))::numeric AS total_logical_reads,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'expensive_queries'::text);

CREATE OR REPLACE VIEW monitoring.v_oracle_transactions AS
 SELECT row_id,
    session_id,
    server,
    login_name,
    status,
    program,
    host_name,
    duration_secs,
    query_text,
    blocking_session,
    entry_date
   FROM ( SELECT r.row_id,
            (j.value ->> 'SESSION_ID'::text) AS session_id,
            (j.value ->> 'SERVER'::text) AS server,
            (j.value ->> 'LOGIN_NAME'::text) AS login_name,
            (j.value ->> 'STATUS'::text) AS status,
            (j.value ->> 'PROGRAM'::text) AS program,
            (j.value ->> 'HOST_NAME'::text) AS host_name,
            (((j.value ->> 'DURATION_SECS'::text))::numeric / (1000000)::numeric) AS duration_secs,
            (j.value ->> 'QUERY_TEXT'::text) AS query_text,
                CASE
                    WHEN (((j.value ->> 'BLOCKING_SESSION'::text))::numeric IS NOT NULL) THEN 'Locked'::text
                    ELSE ''::text
                END AS blocking_session,
            r.entry_date
           FROM (monitoring.general_metric_metadata_results_old r
             CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
          WHERE ((r.metric_name)::text = 'active_transactions'::text)) unnamed_subquery;

CREATE OR REPLACE VIEW monitoring.v_combined_transactions AS
 SELECT active_transactions.row_id,
    active_transactions.server,
    active_transactions.session_id,
    (active_transactions.duration_secs)::numeric AS duration_secs,
    active_transactions.database_name,
    active_transactions.last_request_end_time,
    active_transactions.command,
    active_transactions.program_name,
    active_transactions.query,
    active_transactions.login_name,
    active_transactions.date_entry
   FROM monitoring.active_transactions
UNION ALL
 SELECT expensive_queries.row_id,
    expensive_queries.server,
    NULL::integer AS session_id,
    (expensive_queries.avg_elapsed_time)::numeric AS duration_secs,
    NULL::character varying AS database_name,
    to_timestamp((((expensive_queries.creation_time)::bigint / 1000))::double precision) AS last_request_end_time,
    NULL::character varying AS command,
    NULL::character varying AS program_name,
    expensive_queries.query,
    NULL::character varying AS login_name,
    expensive_queries.entry_date AS date_entry
   FROM monitoring.expensive_queries
UNION ALL
 SELECT v_oracle_transactions.row_id,
    v_oracle_transactions.server,
    (v_oracle_transactions.session_id)::integer AS session_id,
    v_oracle_transactions.duration_secs,
    NULL::character varying AS database_name,
    v_oracle_transactions.entry_date AS last_request_end_time,
    NULL::character varying AS command,
    v_oracle_transactions.program AS program_name,
    v_oracle_transactions.query_text AS query,
    NULL::character varying AS login_name,
    v_oracle_transactions.entry_date AS date_entry
   FROM monitoring.v_oracle_transactions
UNION ALL
 SELECT v_expensive_queries.row_id,
    v_expensive_queries.server,
    NULL::integer AS session_id,
    v_expensive_queries.avg_duration AS duration_secs,
    NULL::character varying AS database_name,
    v_expensive_queries.last_request_end_time,
    NULL::character varying AS command,
    NULL::character varying AS program_name,
    v_expensive_queries.query,
    NULL::character varying AS login_name,
    v_expensive_queries.entry_date AS date_entry
   FROM monitoring.v_expensive_queries;

CREATE OR REPLACE VIEW monitoring.v_connection_count_per_user AS
 SELECT r.server,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'login_name'::text) AS login_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Connection count per user'::text);

CREATE OR REPLACE VIEW monitoring.v_database_restored AS
 SELECT r.server,
    (j.value ->> 'destination_database_name'::text) AS destination_database_name,
    (j.value ->> 'restore_date'::text) AS restore_date,
    (j.value ->> 'backup_start_date'::text) AS backup_start_date,
    (j.value ->> 'backup_finish_date'::text) AS backup_finish_date,
    (j.value ->> 'source_database_name'::text) AS source_database_name,
    (j.value ->> 'backup_file'::text) AS backup_file
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Database restored'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Database restored'::text))));

CREATE OR REPLACE VIEW monitoring.v_duration AS
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
          WHERE ((gmmr.duration_secs > 0) AND (gmmr.blocking_session_id = 0) AND (gmmr.last_request_end_time >= (now() - '1 day'::interval)))
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
  WHERE (seq = 1)
  ORDER BY NULLIF(anomaly_score, (0)::double precision) DESC;

CREATE OR REPLACE VIEW monitoring.v_enabled_sysadmin AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Enabled sysadmin'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Enabled sysadmin'::text))));

CREATE OR REPLACE VIEW monitoring.v_high_number_blocking_transactions AS
 SELECT count(*) AS "Number of blocks",
    server,
    command
   FROM monitoring.v_blocking_transactions
  WHERE (entry_date > (now() - '01:00:00'::interval))
  GROUP BY server, command
 HAVING (count(*) > 10);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'max_configured'::text) AS max_configured,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'connected_minutes'::text) AS connected_minutes,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'current_sessions'::text) AS current_sessions,
    (j.value ->> 'user_connections_counter'::text) AS user_connections_counter,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'current_sessions'::text) AS current_sessions,
    (j.value ->> 'max_configured'::text) AS max_configured,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'avg_idle_minutes'::text) AS avg_idle_minutes,
    (j.value ->> 'idle_count'::text) AS idle_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_hours'::text) AS idle_hours,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc15 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'lock_escalation_desc'::text) AS lock_escalation_desc,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'held_locks'::text) AS held_locks,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'locked_pages_mb'::text) AS locked_pages_mb,
    (j.value ->> 'memory_used_mb'::text) AS memory_used_mb,
    (j.value ->> 'memory_utilization_percentage'::text) AS memory_utilization_percentage,
    (j.value ->> 'process_physical_memory_low'::text) AS process_physical_memory_low,
    (j.value ->> 'process_virtual_memory_low'::text) AS process_virtual_memory_low,
    (j.value ->> 'total_vas_mb'::text) AS total_vas_mb,
    (j.value ->> 'vas_committed_mb'::text) AS vas_committed_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'configured_mb'::text) AS configured_mb,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pct_of_physical'::text) AS pct_of_physical,
    (j.value ->> 'total_physical_mb'::text) AS total_physical_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'allocated_mb'::text) AS allocated_mb,
    (j.value ->> 'clerk_name'::text) AS clerk_name,
    (j.value ->> 'clerk_type'::text) AS clerk_type,
    (j.value ->> 'vm_committed_mb'::text) AS vm_committed_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'available_gb'::text) AS available_gb,
    (j.value ->> 'free_pct'::text) AS free_pct,
    (j.value ->> 'logical_volume_name'::text) AS logical_volume_name,
    (j.value ->> 'total_gb'::text) AS total_gb,
    (j.value ->> 'volume_mount_point'::text) AS volume_mount_point,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'host_distribution'::text) AS host_distribution,
    (j.value ->> 'host_platform'::text) AS host_platform,
    (j.value ->> 'host_release'::text) AS host_release,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'health_status'::text) AS health_status,
    (j.value ->> 'service_account'::text) AS service_account,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'status_desc'::text) AS status_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'buffer_pool_mb'::text) AS buffer_pool_mb,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'target_server_memory_mb'::text) AS target_server_memory_mb,
    (j.value ->> 'total_server_memory_mb'::text) AS total_server_memory_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'file_id'::text) AS file_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'max_val'::text) AS max_val,
    (j.value ->> 'min_val'::text) AS min_val,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc16 AS
 SELECT r.server,
    (j.value ->> 'LogDate'::text) AS "LogDate",
    (j.value ->> 'ProcessInfo'::text) AS "ProcessInfo",
    (j.value ->> 'Text'::text) AS "Text",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_003_rc17 AS
 SELECT r.server,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-003-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'last_startup_time'::text) AS last_startup_time,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'status_desc'::text) AS status_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'LogDate'::text) AS "LogDate",
    (j.value ->> 'ProcessInfo'::text) AS "ProcessInfo",
    (j.value ->> 'Text'::text) AS "Text",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'cumulative_update'::text) AS cumulative_update,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_version'::text) AS product_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'available_gb'::text) AS available_gb,
    (j.value ->> 'total_gb'::text) AS total_gb,
    (j.value ->> 'volume_mount_point'::text) AS volume_mount_point,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'backup_finish_date'::text) AS backup_finish_date,
    (j.value ->> 'backup_start_date'::text) AS backup_start_date,
    (j.value ->> 'backup_type'::text) AS backup_type,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'duration_min'::text) AS duration_min,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'throughput_mb_sec'::text) AS throughput_mb_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'last_startup_time'::text) AS last_startup_time,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'status_desc'::text) AS status_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_005_rc03 AS
 SELECT r.server,
    (j.value ->> 'backup_finish_date'::text) AS backup_finish_date,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'physical_device_name'::text) AS physical_device_name,
    (j.value ->> 'size_gb'::text) AS size_gb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-005-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_005_rc09 AS
 SELECT r.server,
    (j.value ->> 'full_datetime_with_offset'::text) AS full_datetime_with_offset,
    (j.value ->> 'local_time'::text) AS local_time,
    (j.value ->> 'utc_offset_minutes'::text) AS utc_offset_minutes,
    (j.value ->> 'utc_time'::text) AS utc_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-005-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_006_rc08 AS
 SELECT r.server,
    (j.value ->> 'member_name'::text) AS member_name,
    (j.value ->> 'member_state_desc'::text) AS member_state_desc,
    (j.value ->> 'member_type_desc'::text) AS member_type_desc,
    (j.value ->> 'number_of_quorum_votes'::text) AS number_of_quorum_votes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-006-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_007_rc07 AS
 SELECT r.server,
    (j.value ->> 'error_log_path'::text) AS error_log_path,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-007-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_br_007_rc09 AS
 SELECT r.server,
    (j.value ->> 'available_gb'::text) AS available_gb,
    (j.value ->> 'total_gb'::text) AS total_gb,
    (j.value ->> 'volume_mount_point'::text) AS volume_mount_point,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-BR-007-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'running_value'::text) AS running_value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'LogDate'::text) AS "LogDate",
    (j.value ->> 'ProcessInfo'::text) AS "ProcessInfo",
    (j.value ->> 'Text'::text) AS "Text",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'EventSubClass'::text) AS "EventSubClass",
    (j.value ->> 'LoginName'::text) AS "LoginName",
    (j.value ->> 'ObjectName'::text) AS "ObjectName",
    (j.value ->> 'StartTime'::text) AS "StartTime",
    (j.value ->> 'TextData'::text) AS "TextData",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'cumulative_update'::text) AS cumulative_update,
    (j.value ->> 'instance_install_date'::text) AS instance_install_date,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_version'::text) AS product_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'recommendation'::text) AS recommendation,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'local_value'::text) AS local_value,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'maximum'::text) AS maximum,
    (j.value ->> 'minimum'::text) AS minimum,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_close_on'::text) AS is_auto_close_on,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_shrink_on'::text) AS is_auto_shrink_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'is_parameterization_forced'::text) AS is_parameterization_forced,
    (j.value ->> 'is_read_committed_snapshot_on'::text) AS is_read_committed_snapshot_on,
    (j.value ->> 'page_verify_option_desc'::text) AS page_verify_option_desc,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    (j.value ->> 'snapshot_isolation_state_desc'::text) AS snapshot_isolation_state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'is_auto_close_on'::text) AS is_auto_close_on,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_shrink_on'::text) AS is_auto_shrink_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'is_broker_enabled'::text) AS is_broker_enabled,
    (j.value ->> 'is_read_committed_snapshot_on'::text) AS is_read_committed_snapshot_on,
    (j.value ->> 'is_trustworthy_on'::text) AS is_trustworthy_on,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'page_verify_option_desc'::text) AS page_verify_option_desc,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'ansi_nulls_off'::text) AS ansi_nulls_off,
    (j.value ->> 'arithabort_off'::text) AS arithabort_off,
    (j.value ->> 'non_default_isolation'::text) AS non_default_isolation,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'quoted_id_off'::text) AS quoted_id_off,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS "Global",
    (j.value ->> 'Session'::text) AS "Session",
    (j.value ->> 'Status'::text) AS "Status",
    (j.value ->> 'TraceFlag'::text) AS "TraceFlag",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'maximum'::text) AS maximum,
    (j.value ->> 'minimum'::text) AS minimum,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'current_value_mb'::text) AS current_value_mb,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'physical_memory_mb'::text) AS physical_memory_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'batch_requests'::text) AS batch_requests,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'numa_nodes'::text) AS numa_nodes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'low_physical_memory'::text) AS low_physical_memory,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'system_memory_state'::text) AS system_memory_state,
    (j.value ->> 'total_memory_clerks_mb'::text) AS total_memory_clerks_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'current_user_sessions'::text) AS current_user_sessions,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'is_read_committed_snapshot_on'::text) AS is_read_committed_snapshot_on,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'snapshot_isolation_state_desc'::text) AS snapshot_isolation_state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'check_name'::text) AS check_name,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc14 AS
 SELECT r.server,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'running_value'::text) AS running_value,
    (j.value ->> 'server_name'::text) AS server_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'cu_level'::text) AS cu_level,
    (j.value ->> 'last_restart'::text) AS last_restart,
    (j.value ->> 'level'::text) AS level,
    (j.value ->> 'server_name'::text) AS server_name,
    (j.value ->> 'version'::text) AS version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'file_name'::text) AS file_name,
    (j.value ->> 'filegroup_name'::text) AS filegroup_name,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'auth_mode'::text) AS auth_mode,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'check_name'::text) AS check_name,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'principal_name'::text) AS principal_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'role_principal_id'::text) AS role_principal_id,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'default_trace_enabled'::text) AS default_trace_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc14 AS
 SELECT r.server,
    (j.value ->> 'backup_start_date'::text) AS backup_start_date,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc15 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'connections'::text) AS connections,
    (j.value ->> 'unique_logins'::text) AS unique_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc16 AS
 SELECT r.server,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'protocol_type'::text) AS protocol_type,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_004_rc18 AS
 SELECT r.server,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'principal_name'::text) AS principal_name,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-004-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'default_database_name'::text) AS default_database_name,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc02 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'member_name'::text) AS member_name,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'role_name'::text) AS role_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc03 AS
 SELECT r.server,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'principal_id'::text) AS principal_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc04 AS
 SELECT r.server,
    (j.value ->> 'member_count'::text) AS member_count,
    (j.value ->> 'role_name'::text) AS role_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc07 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'role_name'::text) AS role_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc08 AS
 SELECT r.server,
    (j.value ->> 'owner_name'::text) AS owner_name,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc17 AS
 SELECT r.server,
    (j.value ->> 'filename'::text) AS filename,
    (j.value ->> 'service_account'::text) AS service_account,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'status_desc'::text) AS status_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_cd_005_rc20 AS
 SELECT r.server,
    (j.value ->> 'account_type'::text) AS account_type,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_type'::text) AS login_type,
    (j.value ->> 'modify_date'::text) AS modify_date,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-CD-005-RC20'::text);

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
    value_end,
    replace(report_url, '${global_ip}'::text, COALESCE(( SELECT global_params.value
           FROM config.global_params
          WHERE (global_params.key = 'local_ip'::text)), ''::text)) AS report_url
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
            ( SELECT string_agg(DISTINCT TRIM(BOTH FROM rcpt.rcpt), ','::text ORDER BY (TRIM(BOTH FROM rcpt.rcpt))) AS string_agg
                   FROM (config.mail_groups mg
                     CROSS JOIN LATERAL regexp_split_to_table(mg.recipients, '[,;\s]+'::text) rcpt(rcpt))
                  WHERE ((mg.mail_config_id = mc.row_id) AND (mg.is_active = true) AND (length(TRIM(BOTH FROM rcpt.rcpt)) > 0))) AS recipients,
            mc.smtp_password,
            mc.smtp_port,
            mc.smtp_server,
            mc.smtp_user,
            mc.tls,
            mc.mail_sender,
            js.next_run,
            js.last_run,
            r.value_start,
            r.value_end,
            r.report_url
           FROM (((((( SELECT r_1.row_id AS report_id,
                    r_1.report_name,
                    r_1.report_query,
                    a_1.row_id AS alert_id,
                    a_1.alert_name,
                    a_1.alert_query,
                    a_1.value_start,
                    a_1.value_end,
                    r_1.report_url
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
             LEFT JOIN jobs.job_schedules js ON (((js.report_id = r.report_id) AND (js.schedule_id = j.row_id))))) a
  WHERE ((COALESCE(next_run, (now())::timestamp without time zone) <= now()) AND (last_run IS NULL));

CREATE OR REPLACE VIEW monitoring.v_locks AS
 SELECT row_id AS query_id,
    server,
    query,
    reads,
    writes,
    command,
    cpu_time,
    host_name,
    wait_type,
    login_name,
    start_time,
    program_name,
    database_name,
    duration_secs,
    logical_reads,
    last_request_end_time,
    entry_date,
    observed_at,
    columns,
    tables,
    literal,
    condition,
    joins,
    func,
    NULLIF(anomaly_score, (0)::double precision) AS anomaly_score
   FROM ( SELECT row_number() OVER (PARTITION BY a.server, a.query ORDER BY a.duration_secs DESC) AS seq,
            a.row_id,
            a.server,
            a.query,
            a.reads,
            a.writes,
            a.command,
            a.cpu_time,
            a.host_name,
            a.wait_type,
            a.login_name,
            a.start_time,
            a.program_name,
            a.database_name,
            a.duration_secs,
            a.logical_reads,
            a.last_request_end_time,
            a.entry_date,
            a.observed_at,
            a.columns,
            a.tables,
            a.literal,
            a.condition,
            a.joins,
            a.func,
            a.anomaly_score
           FROM ( SELECT gmmr.row_id,
                    gmmr.server,
                    (elem.value ->> 'query'::text) AS query,
                    (elem.value ->> 'reads'::text) AS reads,
                    (elem.value ->> 'writes'::text) AS writes,
                    (elem.value ->> 'command'::text) AS command,
                    (elem.value ->> 'cpu_time'::text) AS cpu_time,
                    (elem.value ->> 'host_name'::text) AS host_name,
                    (elem.value ->> 'wait_type'::text) AS wait_type,
                    (elem.value ->> 'login_name'::text) AS login_name,
                    (elem.value ->> 'start_time'::text) AS start_time,
                    (elem.value ->> 'program_name'::text) AS program_name,
                    (elem.value ->> 'database_name'::text) AS database_name,
                    (elem.value ->> 'duration_secs'::text) AS duration_secs,
                    (elem.value ->> 'logical_reads'::text) AS logical_reads,
                    (elem.value ->> 'last_request_end_time'::text) AS last_request_end_time,
                    gmmr.entry_date,
                    mqp.observed_at,
                    mqp.columns,
                    mqp.tables,
                    mqp.literal,
                    mqp.condition,
                    mqp.joins,
                    mqp.func,
                    NULLIF(sa.anomaly_score, (0)::double precision) AS anomaly_score
                   FROM (((monitoring.general_metric_metadata_results_old gmmr
                     LEFT JOIN LATERAL jsonb_array_elements(gmmr.metric_metadata) elem(value) ON (true))
                     LEFT JOIN monitoring.metric_query_parsing mqp ON ((mqp.query_id = gmmr.row_id)))
                     LEFT JOIN monitoring.autoencoder_sql_anomalies sa ON (((sa.query_id = gmmr.row_id) AND (sa.server = (gmmr.server)::text))))
                  WHERE (((gmmr.metric_name)::text = ANY (ARRAY[('long_locks'::character varying)::text, ('long_locks_blocker'::character varying)::text])) AND (gmmr.entry_date >= (now() - '01:00:00'::interval)) AND (gmmr.entry_date <= now()))
                UNION ALL
                 SELECT gmmr.row_id,
                    gmmr.server,
                    gmmr.query,
                    (gmmr.reads)::text AS reads,
                    (gmmr.writes)::text AS writes,
                    gmmr.command,
                    (gmmr.cpu_time)::text AS cpu_time,
                    gmmr.host_name,
                    gmmr.wait_type,
                    gmmr.login_name,
                    (gmmr.start_time)::text AS start_time,
                    gmmr.program_name,
                    gmmr.database_name,
                    (gmmr.duration_secs)::text AS duration_secs,
                    (gmmr.logical_reads)::text AS logical_reads,
                    (gmmr.last_request_end_time)::text AS last_request_end_time,
                    mqp.entry_date,
                    mqp.observed_at,
                    mqp.columns,
                    mqp.tables,
                    mqp.literal,
                    mqp.condition,
                    mqp.joins,
                    mqp.func,
                    NULLIF(sa.anomaly_score, (0)::double precision) AS anomaly_score
                   FROM ((monitoring.active_transactions gmmr
                     LEFT JOIN monitoring.metric_query_parsing mqp ON ((mqp.query_id = gmmr.row_id)))
                     LEFT JOIN monitoring.autoencoder_sql_anomalies sa ON (((sa.query_id = gmmr.row_id) AND (sa.server = (gmmr.server)::text))))
                  WHERE ((gmmr.duration_secs > 0) AND (gmmr.blocking_session_id <> 0) AND (gmmr.last_request_end_time >= (now() - '1 day'::interval)) AND (gmmr.last_request_end_time <= now()))) a) b
  WHERE (seq = 1);

CREATE OR REPLACE VIEW monitoring.v_logins_with_connect_privilege_login_rights_ AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Logins with CONNECT privilege (LOGIN rights)'::text);

CREATE OR REPLACE VIEW monitoring.v_logins_with_sysadmin_superuser_privileges AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Logins with sysadmin (superuser) privileges'::text);

CREATE OR REPLACE VIEW monitoring.v_long_block_transactions AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'total_elapsed_time'::text) AS total_elapsed_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'long_block_transactions'::text);

CREATE OR REPLACE VIEW monitoring.v_long_locks AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'duration_secs'::text) AS duration_secs,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_wait_type'::text) AS last_wait_type,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'query'::text) AS query,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'long_locks'::text);

CREATE OR REPLACE VIEW monitoring.v_long_locks_blocker AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'duration_secs'::text) AS duration_secs,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_wait_type'::text) AS last_wait_type,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'root_blocker_id'::text) AS root_blocker_id,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'long_locks_blocker'::text);

CREATE OR REPLACE VIEW monitoring.v_mssql_blocking_sessiond AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_resource'::text) AS wait_resource,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Blocking sessions'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Blocking sessions'::text))));

CREATE OR REPLACE VIEW monitoring.v_mssql_credentials_stored_in_tables AS
 SELECT r.server,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Credentials stored in tables'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Credentials stored in tables'::text))));

CREATE OR REPLACE VIEW monitoring.v_mssql_superuser AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Logins with sysadmin (superuser) privileges'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Logins with sysadmin (superuser) privileges'::text))));

CREATE OR REPLACE VIEW monitoring.v_query_history_occurance AS
 SELECT seq,
    columns,
    server,
    tables,
    condition,
    func,
    joins,
    literal,
    table_name,
    hour_of_day,
    login_name,
    query,
    max(seq) OVER (PARTITION BY login_name, columns, server, tables, condition, func, joins, literal, table_name) AS max_seq
   FROM ( SELECT row_number() OVER (PARTITION BY at.login_name, mqp.columns, mqp.server, mqp.tables, mqp.condition, mqp.func, mqp.joins, mqp.literal, mqp.table_name ORDER BY at.last_request_end_time) AS seq,
            mqp.columns,
            mqp.server,
            mqp.tables,
            mqp.condition,
            mqp.func,
            mqp.joins,
            mqp.literal,
            mqp.table_name,
            EXTRACT(hour FROM at.last_request_end_time) AS hour_of_day,
            at.login_name,
            mqp.query
           FROM (monitoring.metric_query_parsing mqp
             JOIN monitoring.active_transactions at ON ((at.row_id = mqp.query_id)))
          WHERE (at.last_request_end_time < (now() - '1 day'::interval))) s;

CREATE OR REPLACE VIEW monitoring.v_new_queries_last_hour AS
 SELECT qho.max_seq,
    a.query_id,
    a.columns,
    a.server,
    a.tables,
    a.condition,
    a.func,
    a.joins,
    a.literal,
    a.table_name,
    a.hour_of_day,
    a.query,
    a.last_request_end_time,
    a.login_name
   FROM (( SELECT row_number() OVER (PARTITION BY at.login_name, mqp.columns, mqp.server, mqp.tables, mqp.condition, mqp.func, mqp.joins, mqp.literal, mqp.table_name) AS seq,
            mqp.query_id,
            mqp.columns,
            mqp.server,
            mqp.tables,
            mqp.condition,
            mqp.func,
            mqp.joins,
            mqp.literal,
            mqp.table_name,
            EXTRACT(hour FROM at.last_request_end_time) AS hour_of_day,
            mqp.query,
            at.last_request_end_time,
            at.login_name
           FROM (monitoring.metric_query_parsing mqp
             JOIN monitoring.active_transactions at ON ((at.row_id = mqp.query_id)))
          WHERE ((at.last_request_end_time > (now() - '1 day'::interval)) AND (EXTRACT(hour FROM at.last_request_end_time) = EXTRACT(hour FROM now())))) a
     LEFT JOIN monitoring.v_query_history_occurance qho ON ((((qho.server)::text = (a.server)::text) AND (qho.tables = a.tables) AND (qho.condition = a.condition) AND (a.func = qho.func) AND (a.joins = qho.joins) AND (a.literal = qho.literal) AND (qho.hour_of_day = a.hour_of_day))))
  WHERE (COALESCE(qho.max_seq, (1)::bigint) = 1);

CREATE OR REPLACE VIEW monitoring.v_oracle_audit_expired AS
 SELECT r.server,
    (j.value ->> 'NAME'::text) AS name,
    (j.value ->> 'SUBJECT'::text) AS account_status,
    (j.value ->> 'ISUSER_NAME'::text) AS lock_date,
    (to_timestamp((((COALESCE(((j.value ->> 'EXPIRY_DATE'::text))::bigint, (0)::bigint))::numeric / 1000.0))::double precision) AT TIME ZONE 'UTC'::text) AS expiry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'audit  expired'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'audit  expired'::text))));

CREATE OR REPLACE VIEW monitoring.v_oracle_locked_accounts AS
 SELECT r.server,
    (j.value ->> 'USERNAME'::text) AS username,
    (j.value ->> 'ACCOUNT_STATUS'::text) AS account_status,
    (j.value ->> 'LOCK_DATE'::text) AS lock_date,
    (to_timestamp((((COALESCE(((j.value ->> 'EXPIRY_DATE'::text))::bigint, (0)::bigint))::numeric / 1000.0))::double precision) AT TIME ZONE 'UTC'::text) AS expiry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'locked_accounts'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'locked_accounts'::text))));

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'buffer_mb'::text) AS buffer_mb,
    (j.value ->> 'buffer_pool_data_mb'::text) AS buffer_pool_data_mb,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'dirty_mb'::text) AS dirty_mb,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'lazy_writes_per_sec'::text) AS lazy_writes_per_sec,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'total_data_files_mb'::text) AS total_data_files_mb,
    (j.value ->> 'total_pages'::text) AS total_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_physical_reads'::text) AS avg_physical_reads,
    (j.value ->> 'avg_rows_returned'::text) AS avg_rows_returned,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'reads_per_row'::text) AS reads_per_row,
    (j.value ->> 'total_logical_reads'::text) AS total_logical_reads,
    (j.value ->> 'total_physical_reads'::text) AS total_physical_reads,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_ideal_grant_kb'::text) AS avg_ideal_grant_kb,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'has_missing_index_hint'::text) AS has_missing_index_hint,
    (j.value ->> 'has_no_join_predicate'::text) AS has_no_join_predicate,
    (j.value ->> 'has_spill_warning'::text) AS has_spill_warning,
    (j.value ->> 'has_warnings'::text) AS has_warnings,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'free_list_stalls_per_sec'::text) AS free_list_stalls_per_sec,
    (j.value ->> 'longest_request_ms'::text) AS longest_request_ms,
    (j.value ->> 'page_io_latch_waiters'::text) AS page_io_latch_waiters,
    (j.value ->> 'page_latch_waiters'::text) AS page_latch_waiters,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'total_active_requests'::text) AS total_active_requests,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_rows_returned'::text) AS avg_rows_returned,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_actual_rows'::text) AS last_actual_rows,
    (j.value ->> 'max_rows'::text) AS max_rows,
    (j.value ->> 'min_rows'::text) AS min_rows,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_spills'::text) AS total_spills,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'forwarded_records_per_sec'::text) AS forwarded_records_per_sec,
    (j.value ->> 'full_scans_per_sec'::text) AS full_scans_per_sec,
    (j.value ->> 'ghost_cleanup_rate'::text) AS ghost_cleanup_rate,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'bg_writer_pages_per_sec'::text) AS bg_writer_pages_per_sec,
    (j.value ->> 'checkpoint_pages_per_sec'::text) AS checkpoint_pages_per_sec,
    (j.value ->> 'lazy_writes_per_sec'::text) AS lazy_writes_per_sec,
    (j.value ->> 'page_writes_per_sec'::text) AS page_writes_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'clerk_name'::text) AS clerk_name,
    (j.value ->> 'clerk_type'::text) AS clerk_type,
    (j.value ->> 'committed_mb'::text) AS committed_mb,
    (j.value ->> 'locked_pages_mb'::text) AS locked_pages_mb,
    (j.value ->> 'memory_low_notification'::text) AS memory_low_notification,
    (j.value ->> 'memory_mb'::text) AS memory_mb,
    (j.value ->> 'memory_utilization_percentage'::text) AS memory_utilization_percentage,
    (j.value ->> 'os_available_memory_mb'::text) AS os_available_memory_mb,
    (j.value ->> 'os_total_memory_mb'::text) AS os_total_memory_mb,
    (j.value ->> 'page_fault_count'::text) AS page_fault_count,
    (j.value ->> 'sql_physical_memory_mb'::text) AS sql_physical_memory_mb,
    (j.value ->> 'system_memory_state_desc'::text) AS system_memory_state_desc,
    (j.value ->> 'virtual_memory_low'::text) AS virtual_memory_low,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'single_use_count'::text) AS single_use_count,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'single_use_size_mb'::text) AS single_use_size_mb,
    (j.value ->> 'total_size_mb'::text) AS total_size_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'exec_plans'::text) AS exec_plans,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'parameterized_plans'::text) AS parameterized_plans,
    (j.value ->> 'plan_kb'::text) AS plan_kb,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'single_use_adhoc'::text) AS single_use_adhoc,
    (j.value ->> 'single_use_mb'::text) AS single_use_mb,
    (j.value ->> 'sql_plan_count'::text) AS sql_plan_count,
    (j.value ->> 'total_cache_objects'::text) AS total_cache_objects,
    (j.value ->> 'usecounts'::text) AS usecounts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'client_interface_name'::text) AS client_interface_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'single_use_cache_mb'::text) AS single_use_cache_mb,
    (j.value ->> 'total_cache_mb'::text) AS total_cache_mb,
    (j.value ->> 'total_single_use_plans'::text) AS total_single_use_plans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'single_use_mb'::text) AS single_use_mb,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_cache_mb'::text) AS total_cache_mb,
    (j.value ->> 'total_plans'::text) AS total_plans,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'cache_mb'::text) AS cache_mb,
    (j.value ->> 'cache_type'::text) AS cache_type,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'temp_proc_cache_mb'::text) AS temp_proc_cache_mb,
    (j.value ->> 'temp_proc_plans'::text) AS temp_proc_plans,
    (j.value ->> 'total_executions'::text) AS total_executions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'active_cursors'::text) AS active_cursors,
    (j.value ->> 'cursor_requests'::text) AS cursor_requests,
    (j.value ->> 'open_cursors_all_sessions'::text) AS open_cursors_all_sessions,
    (j.value ->> 'prepared_plan_cache_mb'::text) AS prepared_plan_cache_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'buffer_pool_mb'::text) AS buffer_pool_mb,
    (j.value ->> 'cache_status'::text) AS cache_status,
    (j.value ->> 'compilations'::text) AS compilations,
    (j.value ->> 'entries_count'::text) AS entries_count,
    (j.value ->> 'entries_in_use_count'::text) AS entries_in_use_count,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pages_in_use_kb'::text) AS pages_in_use_kb,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'plan_stores_mb'::text) AS plan_stores_mb,
    (j.value ->> 'recompilations'::text) AS recompilations,
    (j.value ->> 'total_plan_cache_mb'::text) AS total_plan_cache_mb,
    (j.value ->> 'type'::text) AS type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'active_snapshot_txns'::text) AS active_snapshot_txns,
    (j.value ->> 'current_ghost_records'::text) AS current_ghost_records,
    (j.value ->> 'ghost_cleanup_waiting'::text) AS ghost_cleanup_waiting,
    (j.value ->> 'ghost_records_cleaned'::text) AS ghost_records_cleaned,
    (j.value ->> 'ghost_records_created'::text) AS ghost_records_created,
    (j.value ->> 'oldest_active_txn_sec'::text) AS oldest_active_txn_sec,
    (j.value ->> 'version_store_kb'::text) AS version_store_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'current_ghost_rows'::text) AS current_ghost_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'total_deletes'::text) AS total_deletes,
    (j.value ->> 'total_modifications'::text) AS total_modifications,
    (j.value ->> 'total_updates'::text) AS total_updates,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'highly_modified_stats'::text) AS highly_modified_stats,
    (j.value ->> 'most_recent_update'::text) AS most_recent_update,
    (j.value ->> 'stale_stats_30d'::text) AS stale_stats_30d,
    (j.value ->> 'stale_stats_7d'::text) AS stale_stats_7d,
    (j.value ->> 'total_stats'::text) AS total_stats,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_fragmentation'::text) AS avg_fragmentation,
    (j.value ->> 'indexes_over_30pct'::text) AS indexes_over_30pct,
    (j.value ->> 'indexes_over_50pct'::text) AS indexes_over_50pct,
    (j.value ->> 'indexes_over_80pct'::text) AS indexes_over_80pct,
    (j.value ->> 'total_indexes_checked'::text) AS total_indexes_checked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'entries_count'::text) AS entries_count,
    (j.value ->> 'entries_in_use_count'::text) AS entries_in_use_count,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pages_in_use_kb'::text) AS pages_in_use_kb,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'type'::text) AS type,
    (j.value ->> 'usage_pct'::text) AS usage_pct,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'recompile_ratio'::text) AS recompile_ratio,
    (j.value ->> 'total_elapsed_ms'::text) AS total_elapsed_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'cache_hit_ratio_divisor'::text) AS cache_hit_ratio_divisor,
    (j.value ->> 'cache_pages'::text) AS cache_pages,
    (j.value ->> 'cached_plans_count'::text) AS cached_plans_count,
    (j.value ->> 'clerk_type'::text) AS clerk_type,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pct_of_total_clerks'::text) AS pct_of_total_clerks,
    (j.value ->> 'physical_memory_low'::text) AS physical_memory_low,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'total_kb'::text) AS total_kb,
    (j.value ->> 'type'::text) AS type,
    (j.value ->> 'virtual_memory_low'::text) AS virtual_memory_low,
    (j.value ->> 'vm_committed_kb'::text) AS vm_committed_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'plan_type'::text) AS plan_type,
    (j.value ->> 'single_use_mb'::text) AS single_use_mb,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_size_mb'::text) AS total_size_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'auto_param_attempts_sec'::text) AS auto_param_attempts_sec,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'modification_pct'::text) AS modification_pct,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stats_name'::text) AS stats_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'user_created'::text) AS user_created,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'cmemthread_wait_ms'::text) AS cmemthread_wait_ms,
    (j.value ->> 'cmemthread_waits'::text) AS cmemthread_waits,
    (j.value ->> 'entries_count'::text) AS entries_count,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'plan_size_kb'::text) AS plan_size_kb,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    (j.value ->> 'total_elapsed_ms'::text) AS total_elapsed_ms,
    (j.value ->> 'type'::text) AS type,
    (j.value ->> 'usecounts'::text) AS usecounts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'plan_type'::text) AS plan_type,
    (j.value ->> 'single_use'::text) AS single_use,
    (j.value ->> 'total_mb'::text) AS total_mb,
    (j.value ->> 'wasted_mb'::text) AS wasted_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_kb'::text) AS plan_kb,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'sniffed_value_1'::text) AS sniffed_value_1,
    (j.value ->> 'usecounts'::text) AS usecounts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc12 AS
 SELECT r.server,
    (j.value ->> 'avg_reuse'::text) AS avg_reuse,
    (j.value ->> 'cache_mb'::text) AS cache_mb,
    (j.value ->> 'cached_plans'::text) AS cached_plans,
    (j.value ->> 'cpu_count'::text) AS cpu_count,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'physical_memory_mb'::text) AS physical_memory_mb,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_hours'::text) AS uptime_hours,
    (j.value ->> 'uptime_minutes'::text) AS uptime_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-004-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'default_value'::text) AS default_value,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc04 AS
 SELECT r.server,
    (j.value ->> 'effective_fill_factor'::text) AS effective_fill_factor,
    (j.value ->> 'fill_factor'::text) AS fill_factor,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'leaf_insert_count'::text) AS leaf_insert_count,
    (j.value ->> 'leaf_update_count'::text) AS leaf_update_count,
    (j.value ->> 'page_splits'::text) AS page_splits,
    (j.value ->> 'split_rate_pct'::text) AS split_rate_pct,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc05 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'effective_fill_factor'::text) AS effective_fill_factor,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'leaf_delete_count'::text) AS leaf_delete_count,
    (j.value ->> 'leaf_insert_count'::text) AS leaf_insert_count,
    (j.value ->> 'leaf_update_count'::text) AS leaf_update_count,
    (j.value ->> 'page_splits'::text) AS page_splits,
    (j.value ->> 'split_rate_pct'::text) AS split_rate_pct,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc10 AS
 SELECT r.server,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'insert_pattern'::text) AS insert_pattern,
    (j.value ->> 'leaf_delete_count'::text) AS leaf_delete_count,
    (j.value ->> 'leaf_insert_count'::text) AS leaf_insert_count,
    (j.value ->> 'nonleaf_splits'::text) AS nonleaf_splits,
    (j.value ->> 'page_splits'::text) AS page_splits,
    (j.value ->> 'range_scan_count'::text) AS range_scan_count,
    (j.value ->> 'singleton_lookup_count'::text) AS singleton_lookup_count,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CE-005-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'max_user_connections'::text) AS max_user_connections,
    (j.value ->> 'running_sessions'::text) AS running_sessions,
    (j.value ->> 'sleeping_sessions'::text) AS sleeping_sessions,
    (j.value ->> 'suspended_sessions'::text) AS suspended_sessions,
    (j.value ->> 'total_connections'::text) AS total_connections,
    (j.value ->> 'user_sessions'::text) AS user_sessions,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_since_seconds'::text) AS idle_since_seconds,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_age_seconds'::text) AS transaction_age_seconds,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_state'::text) AS transaction_state,
    (j.value ->> 'transaction_type'::text) AS transaction_type,
    (j.value ->> 'txn_age_seconds'::text) AS txn_age_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'connect_time'::text) AS connect_time,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_age_minutes'::text) AS session_age_minutes,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'max_elapsed_ms'::text) AS max_elapsed_ms,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_elapsed_ms'::text) AS total_elapsed_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_sessions_per_host'::text) AS avg_sessions_per_host,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'earliest_login'::text) AS earliest_login,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'latest_request'::text) AS latest_request,
    (j.value ->> 'max_connections'::text) AS max_connections,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'running'::text) AS running,
    (j.value ->> 'server_total_sessions'::text) AS server_total_sessions,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'sleeping'::text) AS sleeping,
    (j.value ->> 'suspended'::text) AS suspended,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_seconds'::text) AS avg_wait_seconds,
    (j.value ->> 'max_wait_seconds'::text) AS max_wait_seconds,
    (j.value ->> 'total_wait_seconds'::text) AS total_wait_seconds,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'total_wait_seconds'::text) AS total_wait_seconds,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'connect_time'::text) AS connect_time,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_since_minutes'::text) AS idle_since_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_age_minutes'::text) AS session_age_minutes,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_hours'::text) AS idle_hours,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_age_hours'::text) AS session_age_hours,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'txn_status'::text) AS txn_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_state'::text) AS transaction_state,
    (j.value ->> 'txn_age_minutes'::text) AS txn_age_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'connect_time'::text) AS connect_time,
    (j.value ->> 'current_user_connections'::text) AS current_user_connections,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_age_hours'::text) AS session_age_hours,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'stale_sessions_24h'::text) AS stale_sessions_24h,
    (j.value ->> 'stale_sessions_72h'::text) AS stale_sessions_72h,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_query'::text) AS last_query,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'idle_bucket'::text) AS idle_bucket,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'logins_per_sec'::text) AS logins_per_sec,
    (j.value ->> 'logouts_per_sec'::text) AS logouts_per_sec,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'orphaned_sessions'::text) AS orphaned_sessions,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'blocked_session_count'::text) AS blocked_session_count,
    (j.value ->> 'database_transaction_log_bytes_reserved'::text) AS database_transaction_log_bytes_reserved,
    (j.value ->> 'database_transaction_log_bytes_used'::text) AS database_transaction_log_bytes_used,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'log_reuse_wait_desc'::text) AS log_reuse_wait_desc,
    (j.value ->> 'log_since_backup_mb'::text) AS log_since_backup_mb,
    (j.value ->> 'log_used_mb'::text) AS log_used_mb,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    (j.value ->> 'txn_age_minutes'::text) AS txn_age_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc13 AS
 SELECT r.server,
    (j.value ->> 'active_duration_min'::text) AS active_duration_min,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_since_min'::text) AS idle_since_min,
    (j.value ->> 'last_request_duration_sec'::text) AS last_request_duration_sec,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'num_reads'::text) AS num_reads,
    (j.value ->> 'num_writes'::text) AS num_writes,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-002-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'avg_session_age_sec'::text) AS avg_session_age_sec,
    (j.value ->> 'max_session_age_sec'::text) AS max_session_age_sec,
    (j.value ->> 'min_session_age_sec'::text) AS min_session_age_sec,
    (j.value ->> 'program_name'::text) AS program_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'session_age_bucket'::text) AS session_age_bucket,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'current_database'::text) AS current_database,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'sessions_from_host'::text) AS sessions_from_host,
    (j.value ->> 'sleeping_sessions'::text) AS sleeping_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    (j.value ->> 'total_elapsed_ms'::text) AS total_elapsed_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'connection_resets_sec'::text) AS connection_resets_sec,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'logouts_sec'::text) AS logouts_sec,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_connection_age_sec'::text) AS avg_connection_age_sec,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'connection_resets_sec'::text) AS connection_resets_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'logouts_sec'::text) AS logouts_sec,
    (j.value ->> 'max_connection_age_sec'::text) AS max_connection_age_sec,
    (j.value ->> 'min_connection_age_sec'::text) AS min_connection_age_sec,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'connect_minute'::text) AS connect_minute,
    (j.value ->> 'connections_created'::text) AS connections_created,
    (j.value ->> 'earliest_connection'::text) AS earliest_connection,
    (j.value ->> 'latest_connection'::text) AS latest_connection,
    (j.value ->> 'restart_status'::text) AS restart_status,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_minutes'::text) AS uptime_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'avg_age_sec'::text) AS avg_age_sec,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'connection_resets_sec'::text) AS connection_resets_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'logouts_sec'::text) AS logouts_sec,
    (j.value ->> 'min_age_sec'::text) AS min_age_sec,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_uses'::text) AS avg_uses,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'compilation_pct_of_batches'::text) AS compilation_pct_of_batches,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'plan_type'::text) AS plan_type,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'total_size_mb'::text) AS total_size_mb,
    (j.value ->> 'total_uses'::text) AS total_uses,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'connection_resets_sec'::text) AS connection_resets_sec,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'query_prefix'::text) AS query_prefix,
    (j.value ->> 'user_connections'::text) AS user_connections,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'connection_resets_sec'::text) AS connection_resets_sec,
    (j.value ->> 'errors_sec'::text) AS errors_sec,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'logouts_sec'::text) AS logouts_sec,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'active_requests'::text) AS active_requests,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'configured_max_connections'::text) AS configured_max_connections,
    (j.value ->> 'configured_max_workers'::text) AS configured_max_workers,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'current_user_sessions'::text) AS current_user_sessions,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'max_workers_any_scheduler'::text) AS max_workers_any_scheduler,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'sleeping_sessions'::text) AS sleeping_sessions,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'connect_minute'::text) AS connect_minute,
    (j.value ->> 'connections_per_minute'::text) AS connections_per_minute,
    (j.value ->> 'current_login_rate'::text) AS current_login_rate,
    (j.value ->> 'current_sessions'::text) AS current_sessions,
    (j.value ->> 'current_total_connections'::text) AS current_total_connections,
    (j.value ->> 'logins_sec'::text) AS logins_sec,
    (j.value ->> 'logouts_sec'::text) AS logouts_sec,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'severity'::text) AS severity,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'user_errors_sec'::text) AS user_errors_sec,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_connections_per_host'::text) AS avg_connections_per_host,
    (j.value ->> 'avg_connections_per_program'::text) AS avg_connections_per_program,
    (j.value ->> 'configured_max'::text) AS configured_max,
    (j.value ->> 'distinct_client_hosts'::text) AS distinct_client_hosts,
    (j.value ->> 'distinct_programs'::text) AS distinct_programs,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'running_count'::text) AS running_count,
    (j.value ->> 'running_sessions'::text) AS running_sessions,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'sleeping_count'::text) AS sleeping_count,
    (j.value ->> 'sleeping_pct'::text) AS sleeping_pct,
    (j.value ->> 'sleeping_sessions'::text) AS sleeping_sessions,
    (j.value ->> 'total_connections'::text) AS total_connections,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'configured_max_workers'::text) AS configured_max_workers,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'max_workers_per_scheduler'::text) AS max_workers_per_scheduler,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'running_max_workers'::text) AS running_max_workers,
    (j.value ->> 'running_value'::text) AS running_value,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'total_active_workers'::text) AS total_active_workers,
    (j.value ->> 'total_queued_tasks'::text) AS total_queued_tasks,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'admin_tool_sessions'::text) AS admin_tool_sessions,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_category'::text) AS session_category,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'sleeping_count'::text) AS sleeping_count,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'threadpool_waits'::text) AS threadpool_waits,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'max_connections'::text) AS max_connections,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'repl_count'::text) AS repl_count,
    (j.value ->> 'replication_sessions'::text) AS replication_sessions,
    (j.value ->> 'threadpool_waits'::text) AS threadpool_waits,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_hours'::text) AS idle_hours,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'orphaned_estimate'::text) AS orphaned_estimate,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'env_classification'::text) AS env_classification,
    (j.value ->> 'non_prod_pct'::text) AS non_prod_pct,
    (j.value ->> 'non_prod_sessions'::text) AS non_prod_sessions,
    (j.value ->> 'running_count'::text) AS running_count,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'sleeping_count'::text) AS sleeping_count,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_connection_age_min'::text) AS avg_connection_age_min,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'hung_with_open_txn'::text) AS hung_with_open_txn,
    (j.value ->> 'long_lived_sessions'::text) AS long_lived_sessions,
    (j.value ->> 'max_connection_age_min'::text) AS max_connection_age_min,
    (j.value ->> 'open_txn_sessions'::text) AS open_txn_sessions,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'threadpool_waits'::text) AS threadpool_waits,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'max_sessions_single_source'::text) AS max_sessions_single_source,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'current_user_sessions'::text) AS current_user_sessions,
    (j.value ->> 'max_user_connections'::text) AS max_user_connections,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'max_worker_threads'::text) AS max_worker_threads,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'memory_used_mb'::text) AS memory_used_mb,
    (j.value ->> 'resource_governor_enabled'::text) AS resource_governor_enabled,
    (j.value ->> 'total_memory_mb'::text) AS total_memory_mb,
    (j.value ->> 'user_sessions'::text) AS user_sessions,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'worker_utilization_pct'::text) AS worker_utilization_pct,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'available_memory_mb'::text) AS available_memory_mb,
    (j.value ->> 'locked_pages_mb'::text) AS locked_pages_mb,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'memory_utilization_percentage'::text) AS memory_utilization_percentage,
    (j.value ->> 'page_life_expectancy_sec'::text) AS page_life_expectancy_sec,
    (j.value ->> 'process_physical_memory_low'::text) AS process_physical_memory_low,
    (j.value ->> 'process_virtual_memory_low'::text) AS process_virtual_memory_low,
    (j.value ->> 'sql_memory_used_mb'::text) AS sql_memory_used_mb,
    (j.value ->> 'stolen_pages'::text) AS stolen_pages,
    (j.value ->> 'system_high_memory_signal_state'::text) AS system_high_memory_signal_state,
    (j.value ->> 'system_low_memory_signal_state'::text) AS system_low_memory_signal_state,
    (j.value ->> 'target_pages'::text) AS target_pages,
    (j.value ->> 'total_memory_mb'::text) AS total_memory_mb,
    (j.value ->> 'user_errors_sec'::text) AS user_errors_sec,
    (j.value ->> 'user_sessions'::text) AS user_sessions,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_010_rc01 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'connected_sec'::text) AS connected_sec,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'memory_usage'::text) AS memory_usage,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CN-010-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'ci_scan_count'::text) AS ci_scan_count,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'key_lookup_count'::text) AS key_lookup_count,
    (j.value ->> 'query_plan'::text) AS query_plan,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'table_scan_count'::text) AS table_scan_count,
    (j.value ->> 'total_cpu_us'::text) AS total_cpu_us,
    (j.value ->> 'warning_count'::text) AS warning_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'creation_time'::text) AS creation_time,
    (j.value ->> 'EventTime'::text) AS eventtime,
    (j.value ->> 'exec_per_min'::text) AS exec_per_min,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'idle_pct'::text) AS idle_pct,
    (j.value ->> 'other_process_cpu_pct'::text) AS other_process_cpu_pct,
    (j.value ->> 'plan_age_min'::text) AS plan_age_min,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'record_id'::text) AS record_id,
    (j.value ->> 'sql_cpu_pct'::text) AS sql_cpu_pct,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'ci_scans'::text) AS ci_scans,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'nc_scans'::text) AS nc_scans,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'query_plan'::text) AS query_plan,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'table_scans'::text) AS table_scans,
    (j.value ->> 'total_logical_reads'::text) AS total_logical_reads,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'actual_rows'::text) AS actual_rows,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'days_since_update'::text) AS days_since_update,
    (j.value ->> 'estimated_rows'::text) AS estimated_rows,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'pct_modified'::text) AS pct_modified,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'cpu_variance_ratio'::text) AS cpu_variance_ratio,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'max_cpu_ms'::text) AS max_cpu_ms,
    (j.value ->> 'max_reads'::text) AS max_reads,
    (j.value ->> 'min_cpu_ms'::text) AS min_cpu_ms,
    (j.value ->> 'min_reads'::text) AS min_reads,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'pct_of_total_waits'::text) AS pct_of_total_waits,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'udf_operator_count'::text) AS udf_operator_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_spills_per_exec'::text) AS avg_spills_per_exec,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_spills'::text) AS total_spills,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc15 AS
 SELECT r.server,
    (j.value ->> 'available_memory_mb'::text) AS available_memory_mb,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'buffer_cache_hit_ratio'::text) AS buffer_cache_hit_ratio,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'memory_grants_pending'::text) AS memory_grants_pending,
    (j.value ->> 'page_life_expectancy_sec'::text) AS page_life_expectancy_sec,
    (j.value ->> 'resource_semaphore_wait_ms'::text) AS resource_semaphore_wait_ms,
    (j.value ->> 'resource_semaphore_waits'::text) AS resource_semaphore_waits,
    (j.value ->> 'sql_memory_in_use_mb'::text) AS sql_memory_in_use_mb,
    (j.value ->> 'system_memory_state_desc'::text) AS system_memory_state_desc,
    (j.value ->> 'total_memory_mb'::text) AS total_memory_mb,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc17 AS
 SELECT r.server,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc18 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'bg_writer_pages_sec'::text) AS bg_writer_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'log_flushes_sec'::text) AS log_flushes_sec,
    (j.value ->> 'log_reuse_wait_desc'::text) AS log_reuse_wait_desc,
    (j.value ->> 'page_writes_sec'::text) AS page_writes_sec,
    (j.value ->> 'target_recovery_time_in_seconds'::text) AS target_recovery_time_in_seconds,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc19 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'log_bytes_flushed_sec'::text) AS log_bytes_flushed_sec,
    (j.value ->> 'log_flush_wait_ms'::text) AS log_flush_wait_ms,
    (j.value ->> 'log_flushes_sec'::text) AS log_flushes_sec,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transactions_sec'::text) AS transactions_sec,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC19'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc21 AS
 SELECT r.server,
    (j.value ->> 'active_workers_count'::text) AS active_workers_count,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'context_switches_count'::text) AS context_switches_count,
    (j.value ->> 'cpu_id'::text) AS cpu_id,
    (j.value ->> 'current_tasks_count'::text) AS current_tasks_count,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'runnable_tasks_count'::text) AS runnable_tasks_count,
    (j.value ->> 'scheduler_id'::text) AS scheduler_id,
    (j.value ->> 'signal_pct'::text) AS signal_pct,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'switches_per_yield'::text) AS switches_per_yield,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'work_queue_count'::text) AS work_queue_count,
    (j.value ->> 'yield_count'::text) AS yield_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC21'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc22 AS
 SELECT r.server,
    (j.value ->> 'EventTime'::text) AS eventtime,
    (j.value ->> 'hyperthread_ratio'::text) AS hyperthread_ratio,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'OtherProcessCPU'::text) AS otherprocesscpu,
    (j.value ->> 'record_id'::text) AS record_id,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'signal_wait_pct'::text) AS signal_wait_pct,
    (j.value ->> 'SQLProcessUtilization'::text) AS sqlprocessutilization,
    (j.value ->> 'SystemIdle'::text) AS systemidle,
    (j.value ->> 'total_runnable_tasks'::text) AS total_runnable_tasks,
    (j.value ->> 'total_signal_wait_ms'::text) AS total_signal_wait_ms,
    (j.value ->> 'total_wait_ms'::text) AS total_wait_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-001-RC22'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_use_count'::text) AS avg_use_count,
    (j.value ->> 'cacheobjtype'::text) AS cacheobjtype,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_size_mb'::text) AS total_size_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'size_kb'::text) AS size_kb,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'usecounts'::text) AS usecounts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'auto_param_attempts'::text) AS auto_param_attempts,
    (j.value ->> 'auto_update_stats'::text) AS auto_update_stats,
    (j.value ->> 'auto_update_stats_async'::text) AS auto_update_stats_async,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_compile_time'::text) AS last_compile_time,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'recently_recompiled_plans'::text) AS recently_recompiled_plans,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'proc_text'::text) AS proc_text,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'dbid'::text) AS dbid,
    (j.value ->> 'max_avg_cpu_ms'::text) AS max_avg_cpu_ms,
    (j.value ->> 'max_plan_gen'::text) AS max_plan_gen,
    (j.value ->> 'min_avg_cpu_ms'::text) AS min_avg_cpu_ms,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    (j.value ->> 'total_executions'::text) AS total_executions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'total_recompile_cpu_ms'::text) AS total_recompile_cpu_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_compile_time'::text) AS last_compile_time,
    (j.value ->> 'minutes_since_compile'::text) AS minutes_since_compile,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'creation_time'::text) AS creation_time,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'cache_hit_ratio_raw'::text) AS cache_hit_ratio_raw,
    (j.value ->> 'cache_pages'::text) AS cache_pages,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'entries_count'::text) AS entries_count,
    (j.value ->> 'entries_in_use_count'::text) AS entries_in_use_count,
    (j.value ->> 'eviction_status'::text) AS eviction_status,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pages_in_use_kb'::text) AS pages_in_use_kb,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'stolen_memory_kb'::text) AS stolen_memory_kb,
    (j.value ->> 'total_cache_objects'::text) AS total_cache_objects,
    (j.value ->> 'type'::text) AS type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc13 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'low_reuse_prepared_mb'::text) AS low_reuse_prepared_mb,
    (j.value ->> 'low_reuse_prepared_plans'::text) AS low_reuse_prepared_plans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'approx_join_count'::text) AS approx_join_count,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_length_chars'::text) AS query_length_chars,
    (j.value ->> 'query_prefix'::text) AS query_prefix,
    (j.value ->> 'total_cpu_ms'::text) AS total_cpu_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc17 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'inlineable_udfs'::text) AS inlineable_udfs,
    (j.value ->> 'inlining_status'::text) AS inlining_status,
    (j.value ->> 'non_inlineable_udfs'::text) AS non_inlineable_udfs,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc18 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cache_mb'::text) AS cache_mb,
    (j.value ->> 'cache_pages'::text) AS cache_pages,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'entries_count'::text) AS entries_count,
    (j.value ->> 'entries_in_use_count'::text) AS entries_in_use_count,
    (j.value ->> 'in_use_mb'::text) AS in_use_mb,
    (j.value ->> 'pages_in_use_kb'::text) AS pages_in_use_kb,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'total_cached_plans'::text) AS total_cached_plans,
    (j.value ->> 'type'::text) AS type,
    (j.value ->> 'unused_entries'::text) AS unused_entries,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc19 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_exec_cpu_us'::text) AS avg_exec_cpu_us,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'compile_cpu_ms'::text) AS compile_cpu_ms,
    (j.value ->> 'compile_time_ms'::text) AS compile_time_ms,
    (j.value ->> 'creation_time'::text) AS creation_time,
    (j.value ->> 'early_abort'::text) AS early_abort,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_execution_time'::text) AS last_execution_time,
    (j.value ->> 'optim_level'::text) AS optim_level,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'signal_wait_pct'::text) AS signal_wait_pct,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_plans'::text) AS total_plans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC19'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc20 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    (j.value ->> 'procedure_text'::text) AS procedure_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-002-RC20'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'dop'::text) AS dop,
    (j.value ->> 'estimate_row_count'::text) AS estimate_row_count,
    (j.value ->> 'node_id'::text) AS node_id,
    (j.value ->> 'physical_operator_name'::text) AS physical_operator_name,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'thread_id'::text) AS thread_id,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'maximum'::text) AS maximum,
    (j.value ->> 'minimum'::text) AS minimum,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_load_factor'::text) AS avg_load_factor,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'max_load_factor'::text) AS max_load_factor,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'numa_nodes'::text) AS numa_nodes,
    (j.value ->> 'online_schedulers'::text) AS online_schedulers,
    (j.value ->> 'pending_io'::text) AS pending_io,
    (j.value ->> 'runnable_tasks'::text) AS runnable_tasks,
    (j.value ->> 'sockets'::text) AS sockets,
    (j.value ->> 'total_tasks'::text) AS total_tasks,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cores_per_numa'::text) AS cores_per_numa,
    (j.value ->> 'hyperthread_ratio'::text) AS hyperthread_ratio,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'numa_node_count'::text) AS numa_node_count,
    (j.value ->> 'physical_cores'::text) AS physical_cores,
    (j.value ->> 'socket_count'::text) AS socket_count,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'granted'::text) AS granted,
    (j.value ->> 'parallel_grants'::text) AS parallel_grants,
    (j.value ->> 'total_granted_mb'::text) AS total_granted_mb,
    (j.value ->> 'waiting_for_grant'::text) AS waiting_for_grant,
    (j.value ->> 'waiting_required_mb'::text) AS waiting_required_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'free_mb'::text) AS free_mb,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'io_wait_ms'::text) AS io_wait_ms,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'estimate_row_count'::text) AS estimate_row_count,
    (j.value ->> 'node_id'::text) AS node_id,
    (j.value ->> 'physical_operator_name'::text) AS physical_operator_name,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'thread_id'::text) AS thread_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'active_workers_count'::text) AS active_workers_count,
    (j.value ->> 'context_switches_count'::text) AS context_switches_count,
    (j.value ->> 'cpu_count'::text) AS cpu_count,
    (j.value ->> 'cpu_id'::text) AS cpu_id,
    (j.value ->> 'current_tasks_count'::text) AS current_tasks_count,
    (j.value ->> 'load_factor'::text) AS load_factor,
    (j.value ->> 'parallel_queries_now'::text) AS parallel_queries_now,
    (j.value ->> 'runnable_tasks_count'::text) AS runnable_tasks_count,
    (j.value ->> 'scheduler_id'::text) AS scheduler_id,
    (j.value ->> 'scheduler_yield_count'::text) AS scheduler_yield_count,
    (j.value ->> 'scheduler_yield_ms'::text) AS scheduler_yield_ms,
    (j.value ->> 'total_parallel_threads'::text) AS total_parallel_threads,
    (j.value ->> 'work_queue_count'::text) AS work_queue_count,
    (j.value ->> 'yield_count'::text) AS yield_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc16 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'page_lookups_sec'::text) AS page_lookups_sec,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'parallel_scan_queries'::text) AS parallel_scan_queries,
    (j.value ->> 'readaheads_sec'::text) AS readaheads_sec,
    (j.value ->> 'total_scan_threads'::text) AS total_scan_threads,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc18 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc19 AS
 SELECT r.server,
    (j.value ->> 'active_workers_count'::text) AS active_workers_count,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'context_switches_count'::text) AS context_switches_count,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'current_tasks_count'::text) AS current_tasks_count,
    (j.value ->> 'hyperthread_ratio'::text) AS hyperthread_ratio,
    (j.value ->> 'load_factor'::text) AS load_factor,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'numa_node_count'::text) AS numa_node_count,
    (j.value ->> 'parent_node_id'::text) AS parent_node_id,
    (j.value ->> 'physical_cores'::text) AS physical_cores,
    (j.value ->> 'runnable_tasks_count'::text) AS runnable_tasks_count,
    (j.value ->> 'scheduler_id'::text) AS scheduler_id,
    (j.value ->> 'socket_count'::text) AS socket_count,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'yield_count'::text) AS yield_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC19'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc21 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'frequent_parallel_plans'::text) AS frequent_parallel_plans,
    (j.value ->> 'max_worker_threads'::text) AS max_worker_threads,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'threadpool_wait_ms'::text) AS threadpool_wait_ms,
    (j.value ->> 'threadpool_waits'::text) AS threadpool_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC21'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc22 AS
 SELECT r.server,
    (j.value ->> 'buffer_cache_hit_ratio'::text) AS buffer_cache_hit_ratio,
    (j.value ->> 'foreign_committed_kb'::text) AS foreign_committed_kb,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'memory_node_id'::text) AS memory_node_id,
    (j.value ->> 'numa_node_count'::text) AS numa_node_count,
    (j.value ->> 'numa_status'::text) AS numa_status,
    (j.value ->> 'page_lookups_sec'::text) AS page_lookups_sec,
    (j.value ->> 'pages_kb'::text) AS pages_kb,
    (j.value ->> 'physical_cores'::text) AS physical_cores,
    (j.value ->> 'target_kb'::text) AS target_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-003-RC22'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'is_auto_create_stats_incremental_on'::text) AS is_auto_create_stats_incremental_on,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'sample_pct'::text) AS sample_pct,
    (j.value ->> 'stats_name'::text) AS stats_name,
    (j.value ->> 'total_rows'::text) AS total_rows,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'large_tables_with_mods'::text) AS large_tables_with_mods,
    (j.value ->> 'threshold_mode'::text) AS threshold_mode,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'hours_since_update'::text) AS hours_since_update,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'pct_modified'::text) AS pct_modified,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stats_name'::text) AS stats_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'total_rows'::text) AS total_rows,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'column_refs'::text) AS column_refs,
    (j.value ->> 'cpu_variance'::text) AS cpu_variance,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'grant_utilization_pct'::text) AS grant_utilization_pct,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'in_row_mb'::text) AS in_row_mb,
    (j.value ->> 'partition_number'::text) AS partition_number,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'cpu_variance'::text) AS cpu_variance,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_generation_num'::text) AS plan_generation_num,
    (j.value ->> 'read_variance'::text) AS read_variance,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc12 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_incremental_on'::text) AS is_auto_create_stats_incremental_on,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_actual_rows'::text) AS avg_actual_rows,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'cardinality_estimator'::text) AS cardinality_estimator,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'queries_with_spills'::text) AS queries_with_spills,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc15 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'grant_utilization_pct'::text) AS grant_utilization_pct,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc18 AS
 SELECT r.server,
    (j.value ->> 'filter_definition'::text) AS filter_definition,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'index_updates'::text) AS index_updates,
    (j.value ->> 'index_usage'::text) AS index_usage,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stat_last_updated'::text) AS stat_last_updated,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc21 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'deferred_compilation_disabled'::text) AS deferred_compilation_disabled,
    (j.value ->> 'tv_estimation_behavior'::text) AS tv_estimation_behavior,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-CPU-004-RC21'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_read_kb'::text) AS avg_read_kb,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_resource_wait_ms'::text) AS avg_resource_wait_ms,
    (j.value ->> 'avg_total_stall_ms'::text) AS avg_total_stall_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_kb'::text) AS avg_write_kb,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'file_name'::text) AS file_name,
    (j.value ->> 'file_type'::text) AS file_type,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_read_ms'::text) AS avg_read_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'file_name'::text) AS file_name,
    (j.value ->> 'log_avg_write_ms'::text) AS log_avg_write_ms,
    (j.value ->> 'log_file_path'::text) AS log_file_path,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'write_read_ratio'::text) AS write_read_ratio,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_read_ms'::text) AS avg_read_ms,
    (j.value ->> 'avg_write_kb'::text) AS avg_write_kb,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'avg_writelog_ms'::text) AS avg_writelog_ms,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'writelog_waits'::text) AS writelog_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_bytes_per_read'::text) AS avg_bytes_per_read,
    (j.value ->> 'avg_read_ms'::text) AS avg_read_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'io_assessment'::text) AS io_assessment,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'pct_of_total_waits'::text) AS pct_of_total_waits,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_queued_read_ms'::text) AS avg_queued_read_ms,
    (j.value ->> 'avg_queued_write_ms'::text) AS avg_queued_write_ms,
    (j.value ->> 'avg_read_ms'::text) AS avg_read_ms,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'contention_indicator'::text) AS contention_indicator,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'max_iops_per_volume'::text) AS max_iops_per_volume,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'pool_name'::text) AS pool_name,
    (j.value ->> 'read_io_completed_total'::text) AS read_io_completed_total,
    (j.value ->> 'read_io_issued_total'::text) AS read_io_issued_total,
    (j.value ->> 'read_io_queued_total'::text) AS read_io_queued_total,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'write_io_completed_total'::text) AS write_io_completed_total,
    (j.value ->> 'write_io_issued_total'::text) AS write_io_issued_total,
    (j.value ->> 'write_io_queued_total'::text) AS write_io_queued_total,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_read_ms'::text) AS avg_read_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'degradation_pattern'::text) AS degradation_pattern,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'network_io_avg_ms'::text) AS network_io_avg_ms,
    (j.value ->> 'overall_avg_stall_ms'::text) AS overall_avg_stall_ms,
    (j.value ->> 'total_io_mb'::text) AS total_io_mb,
    (j.value ->> 'total_io_ops'::text) AS total_io_ops,
    (j.value ->> 'total_read_mb'::text) AS total_read_mb,
    (j.value ->> 'total_write_mb'::text) AS total_write_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'active_grants_mb'::text) AS active_grants_mb,
    (j.value ->> 'active_memory_grants'::text) AS active_memory_grants,
    (j.value ->> 'avg_resource_semaphore_ms'::text) AS avg_resource_semaphore_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'page_life_expectancy'::text) AS page_life_expectancy,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'page_writes_sec'::text) AS page_writes_sec,
    (j.value ->> 'pending_memory_grants'::text) AS pending_memory_grants,
    (j.value ->> 'resource_semaphore_waits'::text) AS resource_semaphore_waits,
    (j.value ->> 'target_memory_kb'::text) AS target_memory_kb,
    (j.value ->> 'total_memory_kb'::text) AS total_memory_kb,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_writelog_ms'::text) AS avg_writelog_ms,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'log_flush_wait_time_ms'::text) AS log_flush_wait_time_ms,
    (j.value ->> 'log_flush_waits_ms'::text) AS log_flush_waits_ms,
    (j.value ->> 'log_flushes'::text) AS log_flushes,
    (j.value ->> 'log_flushes_sec'::text) AS log_flushes_sec,
    (j.value ->> 'log_writes'::text) AS log_writes,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'writelog_wait_time_ms'::text) AS writelog_wait_time_ms,
    (j.value ->> 'writelog_waits'::text) AS writelog_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'data_drive'::text) AS data_drive,
    (j.value ->> 'data_file_path'::text) AS data_file_path,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'log_drive'::text) AS log_drive,
    (j.value ->> 'log_file_path'::text) AS log_file_path,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'io_stall_write_ms'::text) AS io_stall_write_ms,
    (j.value ->> 'log_mb_written'::text) AS log_mb_written,
    (j.value ->> 'log_writes'::text) AS log_writes,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_writelog_ms'::text) AS avg_writelog_ms,
    (j.value ->> 'logbuffer_wait_ms'::text) AS logbuffer_wait_ms,
    (j.value ->> 'logbuffer_waits'::text) AS logbuffer_waits,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'writelog_wait_ms'::text) AS writelog_wait_ms,
    (j.value ->> 'writelog_waits'::text) AS writelog_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'delayed_durability_desc'::text) AS delayed_durability_desc,
    (j.value ->> 'log_flushes'::text) AS log_flushes,
    (j.value ->> 'log_writes'::text) AS log_writes,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pct_of_total_waits'::text) AS pct_of_total_waits,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'backoffs'::text) AS backoffs,
    (j.value ->> 'collisions'::text) AS collisions,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'sleep_time'::text) AS sleep_time,
    (j.value ->> 'spins'::text) AS spins,
    (j.value ->> 'spins_per_collision'::text) AS spins_per_collision,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_size_bytes'::text) AS avg_write_size_bytes,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'total_log_writes'::text) AS total_log_writes,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'growth_setting'::text) AS growth_setting,
    (j.value ->> 'is_percent_growth'::text) AS is_percent_growth,
    (j.value ->> 'log_size_mb'::text) AS log_size_mb,
    (j.value ->> 'max_size'::text) AS max_size,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'physical_name'::text) AS physical_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_bytes'::text) AS avg_write_bytes,
    (j.value ->> 'log_writes'::text) AS log_writes,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'pct_of_waits'::text) AS pct_of_waits,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'foreign_committed_kb'::text) AS foreign_committed_kb,
    (j.value ->> 'local_pages_kb'::text) AS local_pages_kb,
    (j.value ->> 'memory_node_id'::text) AS memory_node_id,
    (j.value ->> 'numa_node'::text) AS numa_node,
    (j.value ->> 'numa_status'::text) AS numa_status,
    (j.value ->> 'runnable_tasks'::text) AS runnable_tasks,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'target_kb'::text) AS target_kb,
    (j.value ->> 'total_tasks'::text) AS total_tasks,
    (j.value ->> 'workers'::text) AS workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_write_bytes'::text) AS avg_write_bytes,
    (j.value ->> 'avg_write_ms'::text) AS avg_write_ms,
    (j.value ->> 'avg_writelog_ms'::text) AS avg_writelog_ms,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'log_flushes'::text) AS log_flushes,
    (j.value ->> 'log_mb_written'::text) AS log_mb_written,
    (j.value ->> 'log_writes'::text) AS log_writes,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'transactions_sec'::text) AS transactions_sec,
    (j.value ->> 'writelog_total_ms'::text) AS writelog_total_ms,
    (j.value ->> 'writelog_waits'::text) AS writelog_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'avg_data_write_ms'::text) AS avg_data_write_ms,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'avg_writelog_ms'::text) AS avg_writelog_ms,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'database_id'::text) AS database_id,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'elapsed_sec'::text) AS elapsed_sec,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'percent_complete'::text) AS percent_complete,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_sec'::text) AS wait_sec,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'page_life_expectancy'::text) AS page_life_expectancy,
    (j.value ->> 'recovery_interval_min'::text) AS recovery_interval_min,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    (j.value ->> 'target_recovery_time_in_seconds'::text) AS target_recovery_time_in_seconds,
    (j.value ->> 'total_pages'::text) AS total_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_pageiolatch_ms'::text) AS avg_pageiolatch_ms,
    (j.value ->> 'bg_writer_pages_sec'::text) AS bg_writer_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'dirty_mb'::text) AS dirty_mb,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'dirty_ratio'::text) AS dirty_ratio,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'pageiolatch_waits'::text) AS pageiolatch_waits,
    (j.value ->> 'total_buffer_pages'::text) AS total_buffer_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_pageiolatch_write_ms'::text) AS avg_pageiolatch_write_ms,
    (j.value ->> 'bg_writer_pages_sec'::text) AS bg_writer_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'indirect_checkpoint_pages_sec'::text) AS indirect_checkpoint_pages_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'dirty_mb'::text) AS dirty_mb,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'dirty_ratio'::text) AS dirty_ratio,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'total_pages'::text) AS total_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'bg_writer_pages_sec'::text) AS bg_writer_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'dirty_ratio'::text) AS dirty_ratio,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'total_pages'::text) AS total_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_read_microsec'::text) AS avg_read_microsec,
    (j.value ->> 'buffer_mb'::text) AS buffer_mb,
    (j.value ->> 'buffered_pages'::text) AS buffered_pages,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'dirty_pages'::text) AS dirty_pages,
    (j.value ->> 'file_id'::text) AS file_id,
    (j.value ->> 'filegroup_count'::text) AS filegroup_count,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'file_name'::text) AS file_name,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'io_stall_read_ms'::text) AS io_stall_read_ms,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'num_of_bytes_read'::text) AS num_of_bytes_read,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'sessions_waiting_on_latches'::text) AS sessions_waiting_on_latches,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'total_latch_waits'::text) AS total_latch_waits,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_write_latch_ms'::text) AS avg_write_latch_ms,
    (j.value ->> 'bg_writer_pages_sec'::text) AS bg_writer_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'indirect_cp_pages_sec'::text) AS indirect_cp_pages_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'data_size_mb'::text) AS data_size_mb,
    (j.value ->> 'log_reuse_wait_desc'::text) AS log_reuse_wait_desc,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    (j.value ->> 'target_recovery_time_in_seconds'::text) AS target_recovery_time_in_seconds,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_io_stall_ms'::text) AS avg_io_stall_ms,
    (j.value ->> 'bgwriter_pages_sec'::text) AS bgwriter_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'avg_read_latency_ms'::text) AS avg_read_latency_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_latency_ms'::text) AS avg_write_latency_ms,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'page_writes_sec'::text) AS page_writes_sec,
    (j.value ->> 'pending_io_requests'::text) AS pending_io_requests,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'total_io_stall_ms'::text) AS total_io_stall_ms,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'files_per_cpu'::text) AS files_per_cpu,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'tempdb_data_files'::text) AS tempdb_data_files,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_pagelatch_up_ms'::text) AS avg_pagelatch_up_ms,
    (j.value ->> 'cpu_cores'::text) AS cpu_cores,
    (j.value ->> 'pagelatch_up_total_ms'::text) AS pagelatch_up_total_ms,
    (j.value ->> 'pagelatch_up_waits'::text) AS pagelatch_up_waits,
    (j.value ->> 'tempdb_files'::text) AS tempdb_files,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'free_space_mb'::text) AS free_space_mb,
    (j.value ->> 'pagelatch_waits'::text) AS pagelatch_waits,
    (j.value ->> 'tempdb_files'::text) AS tempdb_files,
    (j.value ->> 'used_space_mb'::text) AS used_space_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'extent_allocation_mode'::text) AS extent_allocation_mode,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'sql_version_major'::text) AS sql_version_major,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'tempdb_files'::text) AS tempdb_files,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'tf1118_recommendation'::text) AS tf1118_recommendation,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'file_id'::text) AS file_id,
    (j.value ->> 'file_size_mb'::text) AS file_size_mb,
    (j.value ->> 'free_mb'::text) AS free_mb,
    (j.value ->> 'growth'::text) AS growth,
    (j.value ->> 'is_percent_growth'::text) AS is_percent_growth,
    (j.value ->> 'max_size'::text) AS max_size,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'used_mb'::text) AS used_mb,
    (j.value ->> 'utilization_ratio'::text) AS utilization_ratio,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'alloc_pages'::text) AS alloc_pages,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'dealloc_pages'::text) AS dealloc_pages,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'internal_obj_alloc_pages'::text) AS internal_obj_alloc_pages,
    (j.value ->> 'internal_obj_dealloc_pages'::text) AS internal_obj_dealloc_pages,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'user_obj_alloc_pages'::text) AS user_obj_alloc_pages,
    (j.value ->> 'user_obj_dealloc_pages'::text) AS user_obj_dealloc_pages,
    (j.value ->> 'wait_resource'::text) AS wait_resource,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'free_space_mb'::text) AS free_space_mb,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'internal_obj_kb'::text) AS internal_obj_kb,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'temp_table_creation_rate'::text) AS temp_table_creation_rate,
    (j.value ->> 'tv_behavior'::text) AS tv_behavior,
    (j.value ->> 'user_obj_kb'::text) AS user_obj_kb,
    (j.value ->> 'version_store_kb'::text) AS version_store_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_ideal_grant_kb'::text) AS avg_ideal_grant_kb,
    (j.value ->> 'avg_spills_per_exec'::text) AS avg_spills_per_exec,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'total_spills'::text) AS total_spills,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_logical_writes'::text) AS avg_logical_writes,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'sql_compilations_sec'::text) AS sql_compilations_sec,
    (j.value ->> 'temp_creation_rate'::text) AS temp_creation_rate,
    (j.value ->> 'temp_for_destruction'::text) AS temp_for_destruction,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc12 AS
 SELECT r.server,
    (j.value ->> 'available_memory_kb'::text) AS available_memory_kb,
    (j.value ->> 'granted_memory_kb'::text) AS granted_memory_kb,
    (j.value ->> 'grantee_count'::text) AS grantee_count,
    (j.value ->> 'internal_obj_kb'::text) AS internal_obj_kb,
    (j.value ->> 'internal_obj_pct'::text) AS internal_obj_pct,
    (j.value ->> 'memory_utilization_pct'::text) AS memory_utilization_pct,
    (j.value ->> 'tempdb_size_kb'::text) AS tempdb_size_kb,
    (j.value ->> 'total_memory_kb'::text) AS total_memory_kb,
    (j.value ->> 'used_memory_kb'::text) AS used_memory_kb,
    (j.value ->> 'user_obj_kb'::text) AS user_obj_kb,
    (j.value ->> 'waiter_count'::text) AS waiter_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'written_mb'::text) AS written_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'drive'::text) AS drive,
    (j.value ->> 'drive_letter'::text) AS drive_letter,
    (j.value ->> 'file_path'::text) AS file_path,
    (j.value ->> 'file_type'::text) AS file_type,
    (j.value ->> 'source'::text) AS source,
    (j.value ->> 'total_ios'::text) AS total_ios,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc15 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'temp_creation_rate'::text) AS temp_creation_rate,
    (j.value ->> 'tempdb_memory_optimized'::text) AS tempdb_memory_optimized,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc16 AS
 SELECT r.server,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'is_read_committed_snapshot_on'::text) AS is_read_committed_snapshot_on,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'perf_counter_version_kb'::text) AS perf_counter_version_kb,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'snapshot_isolation_state'::text) AS snapshot_isolation_state,
    (j.value ->> 'snapshot_isolation_state_desc'::text) AS snapshot_isolation_state_desc,
    (j.value ->> 'tempdb_total_kb'::text) AS tempdb_total_kb,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'version_cleanup_rate_kb_sec'::text) AS version_cleanup_rate_kb_sec,
    (j.value ->> 'version_gen_rate_kb_sec'::text) AS version_gen_rate_kb_sec,
    (j.value ->> 'version_store_kb'::text) AS version_store_kb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    (j.value ->> 'version_store_pct'::text) AS version_store_pct,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc17 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'file_id'::text) AS file_id,
    (j.value ->> 'growth'::text) AS growth,
    (j.value ->> 'is_percent_growth'::text) AS is_percent_growth,
    (j.value ->> 'max_file_kb'::text) AS max_file_kb,
    (j.value ->> 'max_size'::text) AS max_size,
    (j.value ->> 'min_file_kb'::text) AS min_file_kb,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'size_kb'::text) AS size_kb,
    (j.value ->> 'total_data_files'::text) AS total_data_files,
    (j.value ->> 'total_ios'::text) AS total_ios,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc18 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'tempdb_data_files'::text) AS tempdb_data_files,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IO-004-RC18'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'hours_since_update'::text) AS hours_since_update,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'modification_pct'::text) AS modification_pct,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stale_stat_count'::text) AS stale_stat_count,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'user_created'::text) AS user_created,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_rows'::text) AS avg_rows,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'selectivity_pct'::text) AS selectivity_pct,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'redundant_index'::text) AS redundant_index,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'write_overhead'::text) AS write_overhead,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'fill_factor_setting'::text) AS fill_factor_setting,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'file_name'::text) AS file_name,
    (j.value ->> 'free_mb'::text) AS free_mb,
    (j.value ->> 'growth'::text) AS growth,
    (j.value ->> 'max_size'::text) AS max_size,
    (j.value ->> 'total_mb'::text) AS total_mb,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'used_mb'::text) AS used_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'elapsed_minutes'::text) AS elapsed_minutes,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'percent_complete'::text) AS percent_complete,
    (j.value ->> 'rebuild_mode'::text) AS rebuild_mode,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'index1'::text) AS index1,
    (j.value ->> 'index1_keys'::text) AS index1_keys,
    (j.value ->> 'index2'::text) AS index2,
    (j.value ->> 'index2_keys'::text) AS index2_keys,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type1'::text) AS type1,
    (j.value ->> 'type2'::text) AS type2,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'index1'::text) AS index1,
    (j.value ->> 'index2'::text) AS index2,
    (j.value ->> 'key_cols_1'::text) AS key_cols_1,
    (j.value ->> 'key_cols_2'::text) AS key_cols_2,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'is_primary_key'::text) AS is_primary_key,
    (j.value ->> 'is_unique'::text) AS is_unique,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'user_scans'::text) AS user_scans,
    (j.value ->> 'user_seeks'::text) AS user_seeks,
    (j.value ->> 'user_updates'::text) AS user_updates,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_005_rc09 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-005-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc03 AS
 SELECT r.server,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'total_wasted_mb'::text) AS total_wasted_mb,
    (j.value ->> 'total_wasted_updates'::text) AS total_wasted_updates,
    (j.value ->> 'unused_index_count'::text) AS unused_index_count,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-006-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc05 AS
 SELECT r.server,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-006-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc10 AS
 SELECT r.server,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-006-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc11 AS
 SELECT r.server,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'pct_modified'::text) AS pct_modified,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'stats_name'::text) AS stats_name,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-006-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_007_rc01 AS
 SELECT r.server,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'index_size_mb'::text) AS index_size_mb,
    (j.value ->> 'key_column_count'::text) AS key_column_count,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'total_key_bytes'::text) AS total_key_bytes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-007-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_007_rc05 AS
 SELECT r.server,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'leading_column'::text) AS leading_column,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-IX-007-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'deadlock_count_recent'::text) AS deadlock_count_recent,
    (j.value ->> 'lock_waits'::text) AS lock_waits,
    (j.value ->> 'total_lock_wait_ms'::text) AS total_lock_wait_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'current_statement'::text) AS current_statement,
    (j.value ->> 'duration_seconds'::text) AS duration_seconds,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'locks_held'::text) AS locks_held,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'objects_locked'::text) AS objects_locked,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'held_locks'::text) AS held_locks,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'elapsed_sec'::text) AS elapsed_sec,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'granted_query_memory'::text) AS granted_query_memory,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'plan_xml'::text) AS plan_xml,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'held_lock_count'::text) AS held_lock_count,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'current_lock_count'::text) AS current_lock_count,
    (j.value ->> 'lock_memory_kb'::text) AS lock_memory_kb,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    (j.value ->> 'total_lock_wait_ms'::text) AS total_lock_wait_ms,
    (j.value ->> 'total_lock_waits'::text) AS total_lock_waits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'held_locks'::text) AS held_locks,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_elapsed_sec'::text) AS session_elapsed_sec,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'txn_duration_sec'::text) AS txn_duration_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_seconds'::text) AS avg_wait_seconds,
    (j.value ->> 'blocked_pct'::text) AS blocked_pct,
    (j.value ->> 'blocked_session_count'::text) AS blocked_session_count,
    (j.value ->> 'blocked_sessions'::text) AS blocked_sessions,
    (j.value ->> 'max_wait_seconds'::text) AS max_wait_seconds,
    (j.value ->> 'sleeping_sessions'::text) AS sleeping_sessions,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-002-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'blocked_sessions'::text) AS blocked_sessions,
    (j.value ->> 'duration_seconds'::text) AS duration_seconds,
    (j.value ->> 'held_locks'::text) AS held_locks,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql_text'::text) AS last_sql_text,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_state'::text) AS transaction_state,
    (j.value ->> 'transaction_type'::text) AS transaction_type,
    (j.value ->> 'txn_duration_seconds'::text) AS txn_duration_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'wait_seconds'::text) AS wait_seconds,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'rcsi_enabled'::text) AS rcsi_enabled,
    (j.value ->> 'snapshot_isolation_state'::text) AS snapshot_isolation_state,
    (j.value ->> 'snapshot_isolation_state_desc'::text) AS snapshot_isolation_state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'deadlock_count'::text) AS deadlock_count,
    (j.value ->> 'first_deadlock'::text) AS first_deadlock,
    (j.value ->> 'last_deadlock'::text) AS last_deadlock,
    (j.value ->> 'time_span_minutes'::text) AS time_span_minutes,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'percent_complete'::text) AS percent_complete,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_seconds'::text) AS wait_seconds,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'total_pending_modifications'::text) AS total_pending_modifications,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_resource_wait_ms'::text) AS avg_resource_wait_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'pct_of_pagelatch_waits'::text) AS pct_of_pagelatch_waits,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'committed_mb'::text) AS committed_mb,
    (j.value ->> 'current_tasks'::text) AS current_tasks,
    (j.value ->> 'foreign_committed_mb'::text) AS foreign_committed_mb,
    (j.value ->> 'foreign_pct'::text) AS foreign_pct,
    (j.value ->> 'memory_node_id'::text) AS memory_node_id,
    (j.value ->> 'pages_mb'::text) AS pages_mb,
    (j.value ->> 'parent_node_id'::text) AS parent_node_id,
    (j.value ->> 'pending_io'::text) AS pending_io,
    (j.value ->> 'runnable_tasks'::text) AS runnable_tasks,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'total_yields'::text) AS total_yields,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'file_count_status'::text) AS file_count_status,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'tempdb_data_files'::text) AS tempdb_data_files,
    (j.value ->> 'tempdb_free_mb'::text) AS tempdb_free_mb,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'io_stall_read_ms'::text) AS io_stall_read_ms,
    (j.value ->> 'io_stall_write_ms'::text) AS io_stall_write_ms,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'resource_wait_ms'::text) AS resource_wait_ms,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'backoffs'::text) AS backoffs,
    (j.value ->> 'collisions'::text) AS collisions,
    (j.value ->> 'signal_pct'::text) AS signal_pct,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'sleep_time'::text) AS sleep_time,
    (j.value ->> 'spinlock_name'::text) AS spinlock_name,
    (j.value ->> 'spins'::text) AS spins,
    (j.value ->> 'spins_per_collision'::text) AS spins_per_collision,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc14 AS
 SELECT r.server,
    (j.value ->> 'avg_load_factor'::text) AS avg_load_factor,
    (j.value ->> 'committed_mb'::text) AS committed_mb,
    (j.value ->> 'foreign_committed_mb'::text) AS foreign_committed_mb,
    (j.value ->> 'latch_class'::text) AS latch_class,
    (j.value ->> 'locked_pages_mb'::text) AS locked_pages_mb,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'memory_node_id'::text) AS memory_node_id,
    (j.value ->> 'numa_node'::text) AS numa_node,
    (j.value ->> 'pages_mb'::text) AS pages_mb,
    (j.value ->> 'runnable_tasks'::text) AS runnable_tasks,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'shared_mb'::text) AS shared_mb,
    (j.value ->> 'total_tasks'::text) AS total_tasks,
    (j.value ->> 'total_yields'::text) AS total_yields,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'waiting_requests_count'::text) AS waiting_requests_count,
    (j.value ->> 'work_queue'::text) AS work_queue,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-004-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc02 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'last_wait_type'::text) AS last_wait_type,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'transaction_duration_sec'::text) AS transaction_duration_sec,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc03 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_since_last_request_sec'::text) AS idle_since_last_request_sec,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_duration_sec'::text) AS transaction_duration_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc04 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'implicit_transactions_on'::text) AS implicit_transactions_on,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc06 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_request_start_time'::text) AS last_request_start_time,
    (j.value ->> 'lock_count'::text) AS lock_count,
    (j.value ->> 'log_bytes_used'::text) AS log_bytes_used,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'resource_type'::text) AS resource_type,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_age_minutes'::text) AS transaction_age_minutes,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc07 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_close_on'::text) AS is_auto_close_on,
    (j.value ->> 'is_auto_shrink_on'::text) AS is_auto_shrink_on,
    (j.value ->> 'isolation_level'::text) AS isolation_level,
    (j.value ->> 'isolation_level_id'::text) AS isolation_level_id,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'rcsi_enabled'::text) AS rcsi_enabled,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'snapshot_isolation_state_desc'::text) AS snapshot_isolation_state_desc,
    (j.value ->> 'transaction_duration_sec'::text) AS transaction_duration_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc13 AS
 SELECT r.server,
    (j.value ->> 'active_grants'::text) AS active_grants,
    (j.value ->> 'avg_resource_sem_wait_ms'::text) AS avg_resource_sem_wait_ms,
    (j.value ->> 'grant_time'::text) AS grant_time,
    (j.value ->> 'granted_memory_kb'::text) AS granted_memory_kb,
    (j.value ->> 'ideal_memory_kb'::text) AS ideal_memory_kb,
    (j.value ->> 'max_used_memory_kb'::text) AS max_used_memory_kb,
    (j.value ->> 'pending_grants'::text) AS pending_grants,
    (j.value ->> 'pending_memory_mb'::text) AS pending_memory_mb,
    (j.value ->> 'query_cost'::text) AS query_cost,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'required_memory_kb'::text) AS required_memory_kb,
    (j.value ->> 'resource_pool'::text) AS resource_pool,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'total_waits'::text) AS total_waits,
    (j.value ->> 'used_memory_kb'::text) AS used_memory_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-LC-005-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'available_physical_mb'::text) AS available_physical_mb,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'low_physical_memory'::text) AS low_physical_memory,
    (j.value ->> 'max_server_memory_mb'::text) AS max_server_memory_mb,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'sql_memory_util_pct'::text) AS sql_memory_util_pct,
    (j.value ->> 'sqlserver_using_mb'::text) AS sqlserver_using_mb,
    (j.value ->> 'system_memory_state'::text) AS system_memory_state,
    (j.value ->> 'total_memory_clerks_mb'::text) AS total_memory_clerks_mb,
    (j.value ->> 'total_physical_mb'::text) AS total_physical_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'buffer_pool_data_mb'::text) AS buffer_pool_data_mb,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'max_memory_mb'::text) AS max_memory_mb,
    (j.value ->> 'page_life_expectancy'::text) AS page_life_expectancy,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'total_data_file_mb'::text) AS total_data_file_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_session_memory_kb'::text) AS avg_session_memory_kb,
    (j.value ->> 'clerk_memory_mb'::text) AS clerk_memory_mb,
    (j.value ->> 'clerk_type'::text) AS clerk_type,
    (j.value ->> 'connection_memory_kb'::text) AS connection_memory_kb,
    (j.value ->> 'total_session_memory_kb'::text) AS total_session_memory_kb,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    (j.value ->> 'user_connections'::text) AS user_connections,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'total_granted_mb'::text) AS total_granted_mb,
    (j.value ->> 'total_server_mb'::text) AS total_server_mb,
    (j.value ->> 'total_used_mb'::text) AS total_used_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'clerk_mb'::text) AS clerk_mb,
    (j.value ->> 'clerk_name'::text) AS clerk_name,
    (j.value ->> 'clerk_type'::text) AS clerk_type,
    (j.value ->> 'committed_vas_mb'::text) AS committed_vas_mb,
    (j.value ->> 'locked_pages_mb'::text) AS locked_pages_mb,
    (j.value ->> 'low_memory_signal'::text) AS low_memory_signal,
    (j.value ->> 'low_vas_signal'::text) AS low_vas_signal,
    (j.value ->> 'memory_utilization_percentage'::text) AS memory_utilization_percentage,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'physical_in_use_mb'::text) AS physical_in_use_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'grants_outstanding'::text) AS grants_outstanding,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'ple'::text) AS ple,
    (j.value ->> 'total_granted_mb'::text) AS total_granted_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'cached_proc_plans'::text) AS cached_proc_plans,
    (j.value ->> 'plan_cache_hit_ratio'::text) AS plan_cache_hit_ratio,
    (j.value ->> 'proc_cache_mb'::text) AS proc_cache_mb,
    (j.value ->> 'recompiles_sec'::text) AS recompiles_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'clerk_mb'::text) AS clerk_mb,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'ghost_cleanup_sec'::text) AS ghost_cleanup_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'type'::text) AS type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'available_mb'::text) AS available_mb,
    (j.value ->> 'current_using_mb'::text) AS current_using_mb,
    (j.value ->> 'max_configured_mb'::text) AS max_configured_mb,
    (j.value ->> 'other_processes_mb'::text) AS other_processes_mb,
    (j.value ->> 'sql_low_memory'::text) AS sql_low_memory,
    (j.value ->> 'sql_using_mb'::text) AS sql_using_mb,
    (j.value ->> 'system_memory_state_desc'::text) AS system_memory_state_desc,
    (j.value ->> 'target_mb'::text) AS target_mb,
    (j.value ->> 'total_physical_mb'::text) AS total_physical_mb,
    (j.value ->> 'total_server_mb'::text) AS total_server_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'connection_memory_mb'::text) AS connection_memory_mb,
    (j.value ->> 'session_memory_mb'::text) AS session_memory_mb,
    (j.value ->> 'token_perm_mb'::text) AS token_perm_mb,
    (j.value ->> 'total_user_sessions'::text) AS total_user_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'longest_txn_sec'::text) AS longest_txn_sec,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tempdb_free_mb'::text) AS tempdb_free_mb,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_type'::text) AS transaction_type,
    (j.value ->> 'version_gen_rate_kb_sec'::text) AS version_gen_rate_kb_sec,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    (j.value ->> 'version_store_reserved_mb'::text) AS version_store_reserved_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'ghost_cleanup_sec'::text) AS ghost_cleanup_sec,
    (j.value ->> 'ple'::text) AS ple,
    (j.value ->> 'total_forwarded_fetches'::text) AS total_forwarded_fetches,
    (j.value ->> 'total_ghost_records'::text) AS total_ghost_records,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'queries_waiting_for_grant'::text) AS queries_waiting_for_grant,
    (j.value ->> 'resource_semaphore_wait_ms'::text) AS resource_semaphore_wait_ms,
    (j.value ->> 'resource_semaphore_waiters'::text) AS resource_semaphore_waiters,
    (j.value ->> 'server_maxdop'::text) AS server_maxdop,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modified_pct'::text) AS modified_pct,
    (j.value ->> 'rows_modified'::text) AS rows_modified,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'table_rows'::text) AS table_rows,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'large_grant_count'::text) AS large_grant_count,
    (j.value ->> 'pending_grants'::text) AS pending_grants,
    (j.value ->> 'resource_semaphore_wait_ms'::text) AS resource_semaphore_wait_ms,
    (j.value ->> 'total_granted_kb'::text) AS total_granted_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'effective_maxdop'::text) AS effective_maxdop,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'numa_nodes'::text) AS numa_nodes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc13 AS
 SELECT r.server,
    (j.value ->> 'included_columns'::text) AS included_columns,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'key_columns'::text) AS key_columns,
    (j.value ->> 'key_lookups'::text) AS key_lookups,
    (j.value ->> 'leaf_insert_count'::text) AS leaf_insert_count,
    (j.value ->> 'range_scan_count'::text) AS range_scan_count,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-002-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'grant_status'::text) AS grant_status,
    (j.value ->> 'grant_wait_ms'::text) AS grant_wait_ms,
    (j.value ->> 'granted_memory_kb'::text) AS granted_memory_kb,
    (j.value ->> 'ideal_memory_kb'::text) AS ideal_memory_kb,
    (j.value ->> 'is_small'::text) AS is_small,
    (j.value ->> 'requested_memory_kb'::text) AS requested_memory_kb,
    (j.value ->> 'required_memory_kb'::text) AS required_memory_kb,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'lazy_writes_per_sec'::text) AS lazy_writes_per_sec,
    (j.value ->> 'max_server_memory_mb'::text) AS max_server_memory_mb,
    (j.value ->> 'memory_utilization_percentage'::text) AS memory_utilization_percentage,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'physical_in_use_mb'::text) AS physical_in_use_mb,
    (j.value ->> 'physical_memory_mb'::text) AS physical_memory_mb,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'signal_wait_time_ms'::text) AS signal_wait_time_ms,
    (j.value ->> 'sql_committed_mb'::text) AS sql_committed_mb,
    (j.value ->> 'sql_target_mb'::text) AS sql_target_mb,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'buffer_pool_coverage_pct'::text) AS buffer_pool_coverage_pct,
    (j.value ->> 'buffer_pool_used_mb'::text) AS buffer_pool_used_mb,
    (j.value ->> 'checkpoint_pages'::text) AS checkpoint_pages,
    (j.value ->> 'free_list_stalls'::text) AS free_list_stalls,
    (j.value ->> 'lazy_writes'::text) AS lazy_writes,
    (j.value ->> 'max_memory_pct_of_physical'::text) AS max_memory_pct_of_physical,
    (j.value ->> 'max_server_memory_mb'::text) AS max_server_memory_mb,
    (j.value ->> 'min_server_memory_mb'::text) AS min_server_memory_mb,
    (j.value ->> 'physical_memory_mb'::text) AS physical_memory_mb,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'sql_committed_mb'::text) AS sql_committed_mb,
    (j.value ->> 'sql_target_mb'::text) AS sql_target_mb,
    (j.value ->> 'total_data_size_mb'::text) AS total_data_size_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cached_mb'::text) AS cached_mb,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'dirty_mb'::text) AS dirty_mb,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'readahead_per_sec'::text) AS readahead_per_sec,
    (j.value ->> 'total_table_scans'::text) AS total_table_scans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'lazy_writes_per_sec'::text) AS lazy_writes_per_sec,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'full_scans_sec'::text) AS full_scans_sec,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'estimated_wasted_pages'::text) AS estimated_wasted_pages,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'total_pages_in_buffer'::text) AS total_pages_in_buffer,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'bgwriter_pages_sec'::text) AS bgwriter_pages_sec,
    (j.value ->> 'checkpoint_pages_sec'::text) AS checkpoint_pages_sec,
    (j.value ->> 'page_writes_sec'::text) AS page_writes_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'total_buffer_pages'::text) AS total_buffer_pages,
    (j.value ->> 'total_wasted_pages'::text) AS total_wasted_pages,
    (j.value ->> 'wasted_mb'::text) AS wasted_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'batch_requests_sec'::text) AS batch_requests_sec,
    (j.value ->> 'page_splits_sec'::text) AS page_splits_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'full_scans_sec'::text) AS full_scans_sec,
    (j.value ->> 'index_seeks_sec'::text) AS index_seeks_sec,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'total_logical_reads'::text) AS total_logical_reads,
    (j.value ->> 'total_physical_reads'::text) AS total_physical_reads,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'current_query'::text) AS current_query,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'internal_alloc_pages'::text) AS internal_alloc_pages,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'tempdb_buffer_mb'::text) AS tempdb_buffer_mb,
    (j.value ->> 'tempdb_buffer_pct'::text) AS tempdb_buffer_pct,
    (j.value ->> 'tempdb_pages_in_buffer'::text) AS tempdb_pages_in_buffer,
    (j.value ->> 'total_alloc_pages'::text) AS total_alloc_pages,
    (j.value ->> 'total_buffer_pages'::text) AS total_buffer_pages,
    (j.value ->> 'user_alloc_pages'::text) AS user_alloc_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_physical_reads'::text) AS avg_physical_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'free_list_stalls_sec'::text) AS free_list_stalls_sec,
    (j.value ->> 'lazy_writes_sec'::text) AS lazy_writes_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'top_operator'::text) AS top_operator,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'active_queries'::text) AS active_queries,
    (j.value ->> 'granted_memory_kb'::text) AS granted_memory_kb,
    (j.value ->> 'grants_outstanding'::text) AS grants_outstanding,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'ideal_memory_kb'::text) AS ideal_memory_kb,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'query_cost'::text) AS query_cost,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'total_granted_memory_mb'::text) AS total_granted_memory_mb,
    (j.value ->> 'used_memory_kb'::text) AS used_memory_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'page_lookups_sec'::text) AS page_lookups_sec,
    (j.value ->> 'page_reads_sec'::text) AS page_reads_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'readahead_pages_sec'::text) AS readahead_pages_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc16 AS
 SELECT r.server,
    (j.value ->> 'avg_pageio_latch_ms'::text) AS avg_pageio_latch_ms,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'sessions_waiting_on_io'::text) AS sessions_waiting_on_io,
    (j.value ->> 'stolen_pages'::text) AS stolen_pages,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-003-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'actual_rows'::text) AS actual_rows,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'avg_unused_grant_kb'::text) AS avg_unused_grant_kb,
    (j.value ->> 'estimated_rows'::text) AS estimated_rows,
    (j.value ->> 'estimation_ratio'::text) AS estimation_ratio,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'internal_alloc_mb'::text) AS internal_alloc_mb,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'temp_table_creation_rate'::text) AS temp_table_creation_rate,
    (j.value ->> 'total_grant_kb'::text) AS total_grant_kb,
    (j.value ->> 'total_internal_alloc_pages'::text) AS total_internal_alloc_pages,
    (j.value ->> 'total_spills'::text) AS total_spills,
    (j.value ->> 'total_used_grant_kb'::text) AS total_used_grant_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'modification_pct'::text) AS modification_pct,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'actual_rows'::text) AS actual_rows,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'max_rows'::text) AS max_rows,
    (j.value ->> 'min_rows'::text) AS min_rows,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'row_count_variance'::text) AS row_count_variance,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_grant_kb'::text) AS last_grant_kb,
    (j.value ->> 'max_grant_kb'::text) AS max_grant_kb,
    (j.value ->> 'max_used_grant_kb'::text) AS max_used_grant_kb,
    (j.value ->> 'min_grant_kb'::text) AS min_grant_kb,
    (j.value ->> 'min_used_grant_kb'::text) AS min_used_grant_kb,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'total_spills'::text) AS total_spills,
    (j.value ->> 'used_grant_variance'::text) AS used_grant_variance,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'grant_utilization_pct'::text) AS grant_utilization_pct,
    (j.value ->> 'hash_operators'::text) AS hash_operators,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'sort_est_row_size'::text) AS sort_est_row_size,
    (j.value ->> 'sort_operators'::text) AS sort_operators,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'convert_expression'::text) AS convert_expression,
    (j.value ->> 'convert_implicit_count'::text) AS convert_implicit_count,
    (j.value ->> 'convert_issue'::text) AS convert_issue,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'implicit_conversion_warnings'::text) AS implicit_conversion_warnings,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'avg_spills'::text) AS avg_spills,
    (j.value ->> 'compute_scalar_count'::text) AS compute_scalar_count,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'non_sargable_pattern'::text) AS non_sargable_pattern,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'scan_count'::text) AS scan_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-MEM-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'current_maxdop'::text) AS current_maxdop,
    (j.value ->> 'hyperthread_ratio'::text) AS hyperthread_ratio,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'maxdop_configured'::text) AS maxdop_configured,
    (j.value ->> 'maxdop_setting'::text) AS maxdop_setting,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'numa_nodes'::text) AS numa_nodes,
    (j.value ->> 'physical_cores'::text) AS physical_cores,
    (j.value ->> 'recommended_maxdop'::text) AS recommended_maxdop,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cpu_usage_pct'::text) AS cpu_usage_pct,
    (j.value ->> 'hyperthread_ratio'::text) AS hyperthread_ratio,
    (j.value ->> 'logical_cpus'::text) AS logical_cpus,
    (j.value ->> 'online_schedulers'::text) AS online_schedulers,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'signal_wait_pct'::text) AS signal_wait_pct,
    (j.value ->> 'total_signal_wait_ms'::text) AS total_signal_wait_ms,
    (j.value ->> 'total_wait_ms'::text) AS total_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_read_stall_ms'::text) AS avg_read_stall_ms,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'avg_write_stall_ms'::text) AS avg_write_stall_ms,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'total_io_stall_ms'::text) AS total_io_stall_ms,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'active_requests'::text) AS active_requests,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'thread_status'::text) AS thread_status,
    (j.value ->> 'total_threads'::text) AS total_threads,
    (j.value ->> 'total_workers'::text) AS total_workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_cache_mb'::text) AS plan_cache_mb,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'single_use_mb'::text) AS single_use_mb,
    (j.value ->> 'single_use_parallel_plans'::text) AS single_use_parallel_plans,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_size_mb'::text) AS total_size_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_dop'::text) AS avg_dop,
    (j.value ->> 'avg_threadpool_wait_ms'::text) AS avg_threadpool_wait_ms,
    (j.value ->> 'concurrent_parallel_queries'::text) AS concurrent_parallel_queries,
    (j.value ->> 'max_dop'::text) AS max_dop,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'max_workers_count'::text) AS max_workers_count,
    (j.value ->> 'running_workers'::text) AS running_workers,
    (j.value ->> 'suspended_workers'::text) AS suspended_workers,
    (j.value ->> 'threadpool_wait_count'::text) AS threadpool_wait_count,
    (j.value ->> 'threadpool_wait_ms'::text) AS threadpool_wait_ms,
    (j.value ->> 'total_parallel_workers'::text) AS total_parallel_workers,
    (j.value ->> 'total_workers'::text) AS total_workers,
    (j.value ->> 'workers_used_pct'::text) AS workers_used_pct,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'partition_count'::text) AS partition_count,
    (j.value ->> 'partition_number'::text) AS partition_number,
    (j.value ->> 'partition_scheme'::text) AS partition_scheme,
    (j.value ->> 'pct_of_total'::text) AS pct_of_total,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'total_rows'::text) AS total_rows,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'active_workers_count'::text) AS active_workers_count,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cpu_id'::text) AS cpu_id,
    (j.value ->> 'current_tasks_count'::text) AS current_tasks_count,
    (j.value ->> 'pending_disk_io_count'::text) AS pending_disk_io_count,
    (j.value ->> 'runnable_tasks_count'::text) AS runnable_tasks_count,
    (j.value ->> 'scheduler_id'::text) AS scheduler_id,
    (j.value ->> 'scheduler_state'::text) AS scheduler_state,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    (j.value ->> 'work_queue_count'::text) AS work_queue_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'active_workers'::text) AS active_workers,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'current_workers'::text) AS current_workers,
    (j.value ->> 'max_worker_threads'::text) AS max_worker_threads,
    (j.value ->> 'preemptive_workers'::text) AS preemptive_workers,
    (j.value ->> 'processes_blocked'::text) AS processes_blocked,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'blocked_request_count'::text) AS blocked_request_count,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'pct_workers_blocked'::text) AS pct_workers_blocked,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'total_workers'::text) AS total_workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'active_user_sessions'::text) AS active_user_sessions,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'connection_resets_per_sec'::text) AS connection_resets_per_sec,
    (j.value ->> 'logins_per_sec'::text) AS logins_per_sec,
    (j.value ->> 'logouts_per_sec'::text) AS logouts_per_sec,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'user_connections'::text) AS user_connections,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_io_wait_ms'::text) AS avg_io_wait_ms,
    (j.value ->> 'buffer_pool_mb'::text) AS buffer_pool_mb,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'server_memory_mb'::text) AS server_memory_mb,
    (j.value ->> 'target_memory_mb'::text) AS target_memory_mb,
    (j.value ->> 'threads_waiting_on_io'::text) AS threads_waiting_on_io,
    (j.value ->> 'total_workers'::text) AS total_workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'long_running_queries'::text) AS long_running_queries,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'pct_workers_orphaned'::text) AS pct_workers_orphaned,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'total_workers'::text) AS total_workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_exclusive_lock_wait_ms'::text) AS avg_exclusive_lock_wait_ms,
    (j.value ->> 'deadlock_count'::text) AS deadlock_count,
    (j.value ->> 'earliest_deadlock'::text) AS earliest_deadlock,
    (j.value ->> 'latest_deadlock'::text) AS latest_deadlock,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'queued_requests'::text) AS queued_requests,
    (j.value ->> 'threads_waiting_on_locks'::text) AS threads_waiting_on_locks,
    (j.value ->> 'total_workers'::text) AS total_workers,
    (j.value ->> 'total_x_lock_wait_ms'::text) AS total_x_lock_wait_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'overallocated_schedulers'::text) AS overallocated_schedulers,
    (j.value ->> 'preemptive_workers'::text) AS preemptive_workers,
    (j.value ->> 'suspended_workers'::text) AS suspended_workers,
    (j.value ->> 'total_context_switches'::text) AS total_context_switches,
    (j.value ->> 'total_yields'::text) AS total_yields,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'grants_outstanding'::text) AS grants_outstanding,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'server_memory_mb'::text) AS server_memory_mb,
    (j.value ->> 'total_granted_mb'::text) AS total_granted_mb,
    (j.value ->> 'total_ideal_mb'::text) AS total_ideal_mb,
    (j.value ->> 'total_requested_mb'::text) AS total_requested_mb,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    (j.value ->> 'waiting_for_grant'::text) AS waiting_for_grant,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_cxpacket_ms'::text) AS avg_cxpacket_ms,
    (j.value ->> 'cxpacket_count'::text) AS cxpacket_count,
    (j.value ->> 'cxpacket_wait_ms'::text) AS cxpacket_wait_ms,
    (j.value ->> 'tempdb_spill_mb'::text) AS tempdb_spill_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_read_latency_ms'::text) AS avg_read_latency_ms,
    (j.value ->> 'avg_write_latency_ms'::text) AS avg_write_latency_ms,
    (j.value ->> 'io_stall_read_ms'::text) AS io_stall_read_ms,
    (j.value ->> 'io_stall_write_ms'::text) AS io_stall_write_ms,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'grants_outstanding'::text) AS grants_outstanding,
    (j.value ->> 'grants_pending'::text) AS grants_pending,
    (j.value ->> 'query_exec_reserved_kb'::text) AS query_exec_reserved_kb,
    (j.value ->> 'target_server_kb'::text) AS target_server_kb,
    (j.value ->> 'total_server_kb'::text) AS total_server_kb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'cpu_count'::text) AS cpu_count,
    (j.value ->> 'pageiolatch_wait_ms'::text) AS pageiolatch_wait_ms,
    (j.value ->> 'pageiolatch_waits'::text) AS pageiolatch_waits,
    (j.value ->> 'pagelatch_wait_ms'::text) AS pagelatch_wait_ms,
    (j.value ->> 'pagelatch_waits'::text) AS pagelatch_waits,
    (j.value ->> 'tempdb_data_files'::text) AS tempdb_data_files,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-PL-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'days_since_update'::text) AS days_since_update,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'mod_pct'::text) AS mod_pct,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'sample_pct'::text) AS sample_pct,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'user_created'::text) AS user_created,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'avg_read_latency_ms'::text) AS avg_read_latency_ms,
    (j.value ->> 'avg_write_latency_ms'::text) AS avg_write_latency_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'num_of_reads'::text) AS num_of_reads,
    (j.value ->> 'num_of_writes'::text) AS num_of_writes,
    (j.value ->> 'physical_name'::text) AS physical_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_us'::text) AS avg_cpu_us,
    (j.value ->> 'avg_elapsed_us'::text) AS avg_elapsed_us,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_io_wait_ms'::text) AS avg_io_wait_ms,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'leaf_allocation_count'::text) AS leaf_allocation_count,
    (j.value ->> 'nonleaf_allocation_count'::text) AS nonleaf_allocation_count,
    (j.value ->> 'page_io_latch_wait_count'::text) AS page_io_latch_wait_count,
    (j.value ->> 'page_io_latch_wait_in_ms'::text) AS page_io_latch_wait_in_ms,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'compilations_sec'::text) AS compilations_sec,
    (j.value ->> 'plan_cache_mb'::text) AS plan_cache_mb,
    (j.value ->> 'recompilations_sec'::text) AS recompilations_sec,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_cached_plans'::text) AS total_cached_plans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'maximum'::text) AS maximum,
    (j.value ->> 'minimum'::text) AS minimum,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'cache_hit_ratio'::text) AS cache_hit_ratio,
    (j.value ->> 'cache_hit_ratio_base'::text) AS cache_hit_ratio_base,
    (j.value ->> 'lazy_writes_per_sec'::text) AS lazy_writes_per_sec,
    (j.value ->> 'page_reads_per_sec'::text) AS page_reads_per_sec,
    (j.value ->> 'ple_seconds'::text) AS ple_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'auto_created_stats'::text) AS auto_created_stats,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'index_stats_only'::text) AS index_stats_only,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'user_created_stats'::text) AS user_created_stats,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'index_name'::text) AS index_name,
    (j.value ->> 'index_status'::text) AS index_status,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'table_rows'::text) AS table_rows,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'user_scans'::text) AS user_scans,
    (j.value ->> 'user_seeks'::text) AS user_seeks,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'days_since_update'::text) AS days_since_update,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'mod_pct'::text) AS mod_pct,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'sample_pct'::text) AS sample_pct,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'user_created'::text) AS user_created,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'cost_threshold_parallelism'::text) AS cost_threshold_parallelism,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'recent_query_count'::text) AS recent_query_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed'::text) AS avg_elapsed,
    (j.value ->> 'database_id'::text) AS database_id,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'max_elapsed_time'::text) AS max_elapsed_time,
    (j.value ->> 'max_logical_reads'::text) AS max_logical_reads,
    (j.value ->> 'min_elapsed_time'::text) AS min_elapsed_time,
    (j.value ->> 'min_logical_reads'::text) AS min_logical_reads,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_create_stats_on'::text) AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on'::text) AS is_auto_update_stats_async_on,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'ce_model'::text) AS ce_model,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'engine_major_version'::text) AS engine_major_version,
    (j.value ->> 'is_query_store_on'::text) AS is_query_store_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'configuration_id'::text) AS configuration_id,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'value_for_secondary'::text) AS value_for_secondary,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'cost_threshold'::text) AS cost_threshold,
    (j.value ->> 'maxdop'::text) AS maxdop,
    (j.value ->> 'online_schedulers'::text) AS online_schedulers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_grant_kb'::text) AS avg_grant_kb,
    (j.value ->> 'avg_ideal_grant_kb'::text) AS avg_ideal_grant_kb,
    (j.value ->> 'avg_spills_per_exec'::text) AS avg_spills_per_exec,
    (j.value ->> 'avg_used_grant_kb'::text) AS avg_used_grant_kb,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'total_spills'::text) AS total_spills,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc14 AS
 SELECT r.server,
    (j.value ->> 'auto_created'::text) AS auto_created,
    (j.value ->> 'column_count'::text) AS column_count,
    (j.value ->> 'columns'::text) AS columns,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_auto_update_stats_on'::text) AS is_auto_update_stats_on,
    (j.value ->> 'most_recent_write'::text) AS most_recent_write,
    (j.value ->> 'oldest_stale_stat'::text) AS oldest_stale_stat,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed'::text) AS avg_elapsed,
    (j.value ->> 'database_id'::text) AS database_id,
    (j.value ->> 'elapsed_variance'::text) AS elapsed_variance,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'max_elapsed_time'::text) AS max_elapsed_time,
    (j.value ->> 'min_elapsed_time'::text) AS min_elapsed_time,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'batch_mgf'::text) AS batch_mgf,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'mgf_status'::text) AS mgf_status,
    (j.value ->> 'row_mgf'::text) AS row_mgf,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'est_rows'::text) AS est_rows,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'plan_dop'::text) AS plan_dop,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'subtree_cost'::text) AS subtree_cost,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'value_for_secondary'::text) AS value_for_secondary,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'avg_elapsed_ms'::text) AS avg_elapsed_ms,
    (j.value ->> 'avg_logical_reads'::text) AS avg_logical_reads,
    (j.value ->> 'cacheobjtype'::text) AS cacheobjtype,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_age_hours'::text) AS plan_age_hours,
    (j.value ->> 'plan_created'::text) AS plan_created,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'query_fragment'::text) AS query_fragment,
    (j.value ->> 'size_in_bytes'::text) AS size_in_bytes,
    (j.value ->> 'usecounts'::text) AS usecounts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'single_use_mb'::text) AS single_use_mb,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'single_use_plans'::text) AS single_use_plans,
    (j.value ->> 'total_adhoc_mb'::text) AS total_adhoc_mb,
    (j.value ->> 'total_adhoc_plans'::text) AS total_adhoc_plans,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc14 AS
 SELECT r.server,
    (j.value ->> 'objtype'::text) AS objtype,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'single_use_count'::text) AS single_use_count,
    (j.value ->> 'single_use_pct'::text) AS single_use_pct,
    (j.value ->> 'total_mb'::text) AS total_mb,
    (j.value ->> 'total_uses'::text) AS total_uses,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-004-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_005_rc13 AS
 SELECT r.server,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'column_type'::text) AS column_type,
    (j.value ->> 'fractional_precision'::text) AS fractional_precision,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'type_notes'::text) AS type_notes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-005-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_007_rc07 AS
 SELECT r.server,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'mod_pct'::text) AS mod_pct,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stats_name'::text) AS stats_name,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-007-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_007_rc17 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'cpu_count'::text) AS cpu_count,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'scheduler_count'::text) AS scheduler_count,
    (j.value ->> 'setting_name'::text) AS setting_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-007-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc01 AS
 SELECT r.server,
    (j.value ->> 'available_mb'::text) AS available_mb,
    (j.value ->> 'granted_mb'::text) AS granted_mb,
    (j.value ->> 'grantee_count'::text) AS grantee_count,
    (j.value ->> 'max_target_mb'::text) AS max_target_mb,
    (j.value ->> 'pool_id'::text) AS pool_id,
    (j.value ->> 'resource_semaphore_id'::text) AS resource_semaphore_id,
    (j.value ->> 'target_memory_mb'::text) AS target_memory_mb,
    (j.value ->> 'timeout_error_count'::text) AS timeout_error_count,
    (j.value ->> 'total_memory_mb'::text) AS total_memory_mb,
    (j.value ->> 'used_mb'::text) AS used_mb,
    (j.value ->> 'waiter_count'::text) AS waiter_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-008-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc05 AS
 SELECT r.server,
    (j.value ->> 'active_parallel_thread_count'::text) AS active_parallel_thread_count,
    (j.value ->> 'max_request_grant_memory_kb'::text) AS max_request_grant_memory_kb,
    (j.value ->> 'pool_id'::text) AS pool_id,
    (j.value ->> 'total_reduced_memgrant_count'::text) AS total_reduced_memgrant_count,
    (j.value ->> 'total_request_count'::text) AS total_request_count,
    (j.value ->> 'workload_group'::text) AS workload_group,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-008-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc14 AS
 SELECT r.server,
    (j.value ->> 'cxpacket_wait_ms'::text) AS cxpacket_wait_ms,
    (j.value ->> 'cxpacket_waits'::text) AS cxpacket_waits,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_scoped_maxdop'::text) AS db_scoped_maxdop,
    (j.value ->> 'resource_sem_wait_ms'::text) AS resource_sem_wait_ms,
    (j.value ->> 'resource_sem_waits'::text) AS resource_sem_waits,
    (j.value ->> 'server_maxdop'::text) AS server_maxdop,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-008-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc17 AS
 SELECT r.server,
    (j.value ->> 'current_rows'::text) AS current_rows,
    (j.value ->> 'days_since_update'::text) AS days_since_update,
    (j.value ->> 'last_updated'::text) AS last_updated,
    (j.value ->> 'modification_counter'::text) AS modification_counter,
    (j.value ->> 'modification_pct'::text) AS modification_pct,
    (j.value ->> 'rows_sampled'::text) AS rows_sampled,
    (j.value ->> 'stat_name'::text) AS stat_name,
    (j.value ->> 'stat_rows'::text) AS stat_rows,
    (j.value ->> 'table_name'::text) AS table_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-QE-008-RC17'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'current_query'::text) AS current_query,
    (j.value ->> 'est_remaining_sec'::text) AS est_remaining_sec,
    (j.value ->> 'granted_memory_kb'::text) AS granted_memory_kb,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'query_cpu_sec'::text) AS query_cpu_sec,
    (j.value ->> 'query_elapsed_sec'::text) AS query_elapsed_sec,
    (j.value ->> 'query_running_sec'::text) AS query_running_sec,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'txn_open_sec'::text) AS txn_open_sec,
    (j.value ->> 'wait_resource'::text) AS wait_resource,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'cntr_value'::text) AS cntr_value,
    (j.value ->> 'counter_name'::text) AS counter_name,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'blocking_session_id'::text) AS blocking_session_id,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'duration_sec'::text) AS duration_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'tran_name'::text) AS tran_name,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'protocol_type'::text) AS protocol_type,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'txn_duration_sec'::text) AS txn_duration_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'age_minutes'::text) AS age_minutes,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'avg_log_write_ms'::text) AS avg_log_write_ms,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'log_flushes_sec'::text) AS log_flushes_sec,
    (j.value ->> 'total_log_written_mb'::text) AS total_log_written_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'last_log_backup'::text) AS last_log_backup,
    (j.value ->> 'log_reuse_wait_desc'::text) AS log_reuse_wait_desc,
    (j.value ->> 'log_used_mb'::text) AS log_used_mb,
    (j.value ->> 'log_used_pct'::text) AS log_used_pct,
    (j.value ->> 'minutes_since_log_backup'::text) AS minutes_since_log_backup,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'current_size_mb'::text) AS current_size_mb,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'growth'::text) AS growth,
    (j.value ->> 'growth_desc'::text) AS growth_desc,
    (j.value ->> 'is_percent_growth'::text) AS is_percent_growth,
    (j.value ->> 'max_size'::text) AS max_size,
    (j.value ->> 'max_size_desc'::text) AS max_size_desc,
    (j.value ->> 'physical_name'::text) AS physical_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'session_status'::text) AS session_status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    (j.value ->> 'txn_age_minutes'::text) AS txn_age_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'connect_time'::text) AS connect_time,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_minutes'::text) AS idle_minutes,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_seconds'::text) AS wait_seconds,
    (j.value ->> 'wait_type'::text) AS wait_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'avg_txn_age_minutes'::text) AS avg_txn_age_minutes,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'max_txn_age_minutes'::text) AS max_txn_age_minutes,
    (j.value ->> 'orphaned_txn_count'::text) AS orphaned_txn_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'total_open_txns'::text) AS total_open_txns,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'transaction_name'::text) AS transaction_name,
    (j.value ->> 'txn_age_minutes'::text) AS txn_age_minutes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_seconds'::text) AS idle_seconds,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'last_sql'::text) AS last_sql,
    (j.value ->> 'open_transaction_count'::text) AS open_transaction_count,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'txn_age_seconds'::text) AS txn_age_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'deadlock_pct_of_txn'::text) AS deadlock_pct_of_txn,
    (j.value ->> 'total_deadlocks'::text) AS total_deadlocks,
    (j.value ->> 'txn_per_sec'::text) AS txn_per_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'lock_wait_time_ms'::text) AS lock_wait_time_ms,
    (j.value ->> 'lock_waits_per_sec'::text) AS lock_waits_per_sec,
    (j.value ->> 'total_lock_timeouts'::text) AS total_lock_timeouts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'active_txn'::text) AS active_txn,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'total_txn_per_sec'::text) AS total_txn_per_sec,
    (j.value ->> 'user_errors_per_sec'::text) AS user_errors_per_sec,
    (j.value ->> 'write_txn'::text) AS write_txn,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'log_bytes_flushed_sec'::text) AS log_bytes_flushed_sec,
    (j.value ->> 'log_reuse_wait_desc'::text) AS log_reuse_wait_desc,
    (j.value ->> 'transactions_sec'::text) AS transactions_sec,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'max_workers'::text) AS max_workers,
    (j.value ->> 'memory_low'::text) AS memory_low,
    (j.value ->> 'memory_state'::text) AS memory_state,
    (j.value ->> 'resource_semaphore_ms'::text) AS resource_semaphore_ms,
    (j.value ->> 'threadpool_ms'::text) AS threadpool_ms,
    (j.value ->> 'total_workers'::text) AS total_workers,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc09 AS
 SELECT r.server,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'avg_wait_ms'::text) AS avg_wait_ms,
    (j.value ->> 'max_wait_time_ms'::text) AS max_wait_time_ms,
    (j.value ->> 'wait_time_ms'::text) AS wait_time_ms,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'waiting_tasks_count'::text) AS waiting_tasks_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'connection_resets_per_sec'::text) AS connection_resets_per_sec,
    (j.value ->> 'current_user_connections'::text) AS current_user_connections,
    (j.value ->> 'logins_per_sec'::text) AS logins_per_sec,
    (j.value ->> 'logouts_per_sec'::text) AS logouts_per_sec,
    (j.value ->> 'reset_pct_of_logins'::text) AS reset_pct_of_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_010_rc01 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'cpu_time'::text) AS cpu_time,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'elapsed_sec'::text) AS elapsed_sec,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'reads'::text) AS reads,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'wait_time'::text) AS wait_time,
    (j.value ->> 'wait_type'::text) AS wait_type,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'PERF-SQL-TX-010-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_policy_enforeced AS
 SELECT r.server,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'name'::text) AS name
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'SQL Logins without password policy enforcement'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'SQL Logins without password policy enforcement'::text))));

CREATE OR REPLACE VIEW monitoring.v_public_access_to_tables AS
 SELECT r.server,
    (j.value ->> 'grantee'::text) AS grantee,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'permission_name'::text) AS permission_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'Public access to tables'::text);

CREATE OR REPLACE VIEW monitoring.v_recent_active_sessions AS
 SELECT r.server AS server_name,
    rc.vendor_name AS vendor,
    (j.value ->> 'db_user'::text) AS db_user,
    (j.value ->> 'client_ip'::text) AS client_ip,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'sql_text'::text) AS sql_text,
    (j.value ->> 'session_id'::text) AS session_id,
    rc.root_cause_id,
    r.entry_date AS collected_at
   FROM ((monitoring.general_metric_metadata_results_old r
     JOIN rootcause.v_rootcauses rc ON (((rc.root_cause_id)::text = (r.metric_name)::text)))
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((rc.domain_code)::text = 'SEC'::text) AND ((rc.area_code)::text = ANY (ARRAY[('ACC'::character varying)::text, ('CONN'::character varying)::text, ('AU'::character varying)::text, ('AUTH'::character varying)::text])) AND (r.entry_date >= (now() - '00:02:00'::interval)));

CREATE OR REPLACE VIEW monitoring.v_recent_privileged_logins AS
 SELECT r.server AS server_name,
    rc.vendor_name AS vendor,
    (j.value ->> 'db_user'::text) AS db_user,
    (j.value ->> 'client_ip'::text) AS client_ip,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'role_name'::text) AS role_name,
    rc.root_cause_id,
    r.entry_date AS collected_at
   FROM ((monitoring.general_metric_metadata_results_old r
     JOIN rootcause.v_rootcauses rc ON (((rc.root_cause_id)::text = (r.metric_name)::text)))
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((rc.domain_code)::text = 'SEC'::text) AND ((rc.area_code)::text = ANY (ARRAY[('PRI'::character varying)::text, ('AZ'::character varying)::text, ('AUTHZ'::character varying)::text])) AND (r.entry_date >= (now() - '00:02:00'::interval)));

CREATE OR REPLACE VIEW monitoring.v_recent_sql_injection AS
 SELECT r.server AS server_name,
    rc.vendor_name AS vendor,
    (j.value ->> 'db_user'::text) AS db_user,
    (j.value ->> 'client_ip'::text) AS client_ip,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'sql_text'::text) AS sql_text,
    rc.root_cause_id,
    r.entry_date AS collected_at
   FROM ((monitoring.general_metric_metadata_results_old r
     JOIN rootcause.v_rootcauses rc ON (((rc.root_cause_id)::text = (r.metric_name)::text)))
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((rc.area_code)::text = 'INJ'::text) AND (r.entry_date >= (now() - '00:02:00'::interval)));

CREATE OR REPLACE VIEW monitoring.v_risk_score_trend AS
 SELECT server_name,
    db_user,
    date_trunc('hour'::text, event_time) AS hour_bucket,
    (avg(risk_score))::smallint AS avg_risk,
    max(risk_score) AS peak_risk,
    sum(active_queries) AS total_queries
   FROM monitoring.user_risk_events
  WHERE (event_time >= (now() - '24:00:00'::interval))
  GROUP BY server_name, db_user, (date_trunc('hour'::text, event_time))
  ORDER BY (date_trunc('hour'::text, event_time)) DESC, (max(risk_score)) DESC;

CREATE OR REPLACE VIEW monitoring.v_safe_queries AS
 SELECT query,
    dangerous_function,
    length,
    sleep_time,
    upper_ratio,
    boolean_sqli,
    long_literal,
    num_comments,
    num_keywords,
    num_literals,
    outfile_copy,
    union_select,
    schema_access,
    stacked_query,
    commented_payload,
    sensitive_columns
   FROM ( SELECT (sql_feature_predictions.features ->> 'query'::text) AS query,
            ((sql_feature_predictions.features ->> 'dangerous_function'::text))::boolean AS dangerous_function,
            ((sql_feature_predictions.features ->> 'length'::text))::integer AS length,
            ((sql_feature_predictions.features ->> 'sleep_time'::text))::boolean AS sleep_time,
            ((sql_feature_predictions.features ->> 'upper_ratio'::text))::numeric(12,10) AS upper_ratio,
            ((sql_feature_predictions.features ->> 'boolean_sqli'::text))::boolean AS boolean_sqli,
            ((sql_feature_predictions.features ->> 'long_literal'::text))::boolean AS long_literal,
            ((sql_feature_predictions.features ->> 'num_comments'::text))::integer AS num_comments,
            ((sql_feature_predictions.features ->> 'num_keywords'::text))::integer AS num_keywords,
            ((sql_feature_predictions.features ->> 'num_literals'::text))::integer AS num_literals,
            ((sql_feature_predictions.features ->> 'outfile_copy'::text))::boolean AS outfile_copy,
            ((sql_feature_predictions.features ->> 'union_select'::text))::boolean AS union_select,
            ((sql_feature_predictions.features ->> 'schema_access'::text))::boolean AS schema_access,
            ((sql_feature_predictions.features ->> 'stacked_query'::text))::boolean AS stacked_query,
            ((sql_feature_predictions.features ->> 'commented_payload'::text))::boolean AS commented_payload,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  WHERE ((sensitive_columns IS FALSE) OR (dangerous_function IS FALSE) OR (commented_payload IS FALSE));

CREATE OR REPLACE VIEW monitoring.v_scan_jobs_for_leak AS
 SELECT r.server,
    (j.value ->> 'job_name'::text) AS job_name,
    (j.value ->> 'step_name'::text) AS step_name,
    (j.value ->> 'command'::text) AS command,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'Scan SQL Agent jobs for leak'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'Scan SQL Agent jobs for leak'::text))));

CREATE OR REPLACE VIEW monitoring.v_schema_routines AS
 SELECT routine_name,
    routine_definition,
    routine_catalog,
    routine_schema,
    entry_date
   FROM ( SELECT row_number() OVER (PARTITION BY unnamed_subquery_1.routine_name ORDER BY unnamed_subquery_1.entry_date DESC) AS seq,
            unnamed_subquery_1.routine_name,
            unnamed_subquery_1.routine_definition,
            unnamed_subquery_1.routine_catalog,
            unnamed_subquery_1.routine_schema,
            unnamed_subquery_1.entry_date
           FROM ( SELECT r.server,
                    (j.value ->> 'CREATED'::text) AS created,
                    (j.value ->> 'ROUTINE_NAME'::text) AS routine_name,
                    (j.value ->> 'ROUTINE_DEFINITION'::text) AS routine_definition,
                    (j.value ->> 'ROUTINE_CATALOG'::text) AS routine_catalog,
                    (j.value ->> 'ROUTINE_SCHEMA'::text) AS routine_schema,
                    r.entry_date
                   FROM (monitoring.general_metric_metadata_results_old r
                     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
                  WHERE ((r.metric_name)::text = 'mssql_schema_routines'::text)) unnamed_subquery_1) unnamed_subquery
  WHERE (seq = 1);

CREATE OR REPLACE VIEW monitoring.v_se_sql_az_002_rc11_11 AS
 SELECT (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'permission_count'::text) AS permission_count,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-002-RC11-11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc07 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'trx_user'::text)) AS username,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'trx_host'::text)) AS host,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    to_timestamp(((((COALESCE((j.value ->> 'xact_start'::text), (j.value ->> 'transaction_begin_time'::text), (j.value ->> 'start_time'::text), (j.value ->> 'trx_started'::text)))::bigint)::numeric / 1000.0))::double precision) AS transaction_start,
    ((j.value ->> 'duration_seconds'::text))::integer AS duration_seconds,
    to_timestamp((((j.value ->> 'start_hour'::text))::bigint)::double precision) AS start_hour,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'trx_state'::text)) AS state,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'SEC-SQL-ACC-010-RC07'::text) AND (lower(COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'trx_host'::text))) <> 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc09 AS
 SELECT r.server,
    (j.value ->> 'current_statement'::text) AS current_statement,
    (j.value ->> 'elapsed_ms'::text) AS elapsed_ms,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'logical_reads'::text) AS logical_reads,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'writes'::text) AS writes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ACC-010-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc10 AS
 SELECT r.server,
    (j.value ->> 'host_count'::text) AS host_count,
    (j.value ->> 'hosts'::text) AS hosts,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ACC-010-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc11 AS
 SELECT r.server,
    (j.value ->> 'session_id'::text) AS session_id,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'usename'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'client_addr'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'application_name'::text)) AS application_name,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 1000.0))::double precision) AS start_time,
    COALESCE((j.value ->> 'query_text'::text), (j.value ->> 'query'::text)) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'SEC-SQL-ACC-010-RC11'::text) AND (COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'client_addr'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) <> 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc12 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS username,
    (j.value ->> 'host_name'::text) AS host,
    (j.value ->> 'program_name'::text) AS application_name,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    to_timestamp((((((j.value ->> 'last_request_start_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_request_start_time,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'days_since_modified'::text))::bigint)::numeric / 3.0))::double precision) AS days_since_modified,
    COALESCE((j.value ->> 'sid'::text), (j.value ->> 'trx_id'::text), (j.value ->> 'trx_mysql_thread_id'::text)) AS session_id,
    COALESCE((j.value ->> 'status'::text), (j.value ->> 'trx_state'::text)) AS state,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    (j.value ->> 'seconds_in_wait'::text) AS seconds_in_wait,
    (j.value ->> 'sql_text'::text) AS query_text,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'total_size_bytes'::text) AS total_size_bytes,
    (j.value ->> 'free_space_bytes'::text) AS free_space_bytes,
    (j.value ->> 'open_seconds'::text) AS open_seconds,
    (j.value ->> 'trx_query'::text) AS trx_query,
    (j.value ->> 'trx_rows_locked'::text) AS trx_rows_locked,
    to_timestamp((((((j.value ->> 'trx_rows_modified'::text))::bigint)::numeric / 3.0))::double precision) AS trx_rows_modified,
    (j.value ->> 'trx_isolation_level'::text) AS trx_isolation_level,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-ACC-010-RC12'::text) AND ((j.value ->> 'host_name'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc13 AS
 SELECT r.server,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'constraint_name'::text) AS constraint_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'login_name'::text) AS username,
    (j.value ->> 'host_name'::text) AS host,
    (j.value ->> 'program_name'::text) AS application_name,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    to_timestamp((((((j.value ->> 'transaction_begin_time'::text))::bigint)::numeric / 3.0))::double precision) AS transaction_begin_time,
    (j.value ->> 'duration_seconds'::text) AS duration_seconds,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-ACC-010-RC13'::text) AND ((j.value ->> 'host_name'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_011_rc02 AS
 SELECT r.server,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'duration_seconds'::text) AS duration_seconds,
    (j.value ->> 'transaction_state'::text) AS transaction_state,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ACC-011-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'account_locked'::text) AS account_locked,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'usertype'::text) AS usertype,
    (j.value ->> 'password_expired'::text) AS password_expired,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'days_until_expiration'::text) AS days_until_expiration,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC01'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc01_1 AS
 SELECT (j.value ->> 'sa_not_renamed'::text) AS sa_not_renamed,
    (j.value ->> 'cross_db_chaining'::text) AS cross_db_chaining,
    (j.value ->> 'dac_remote_enabled'::text) AS dac_remote_enabled,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    (j.value ->> 'account_category'::text) AS account_category,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 1000.0))::double precision) AS password_last_set,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC01-1'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'banner'::text) AS banner,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'authentication_string'::text) AS authentication_string,
    (j.value ->> 'parameter'::text) AS parameter,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolpassword_is_not_null'::text) AS rolpassword_is_not_null,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC02'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    (j.value ->> 'machine'::text) AS machine,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'protocol_desc'::text) AS protocol_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'is_dynamic_port'::text) AS is_dynamic_port,
    (j.value ->> 'is_admin_endpoint'::text) AS is_admin_endpoint,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'default_passwords'::text) AS default_passwords,
    (j.value ->> 'issue_count'::text) AS issue_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolreplication'::text) AS rolreplication,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolconnlimit'::text) AS rolconnlimit,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'account_purpose'::text) AS account_purpose,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'account_locked'::text) AS account_locked,
    (j.value ->> 'password_expired'::text) AS password_expired,
    (j.value ->> 'password_lifetime'::text) AS password_lifetime,
    (j.value ->> 'account_type'::text) AS account_type,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'default_tablespace'::text) AS default_tablespace,
    (j.value ->> 'oracle_maintained'::text) AS oracle_maintained,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC05'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'mixed_audit_modes'::text) AS mixed_audit_modes,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc07 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'account_locked'::text) AS account_locked,
    (j.value ->> 'password_expired'::text) AS password_expired,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'active_sa_sessions'::text) AS active_sa_sessions,
    (j.value ->> 'most_recent_sa_login'::text) AS most_recent_sa_login,
    (j.value ->> 'guarantee_flashback_database'::text) AS guarantee_flashback_database,
    (j.value ->> 'storage_size'::text) AS storage_size,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    to_timestamp((((((j.value ->> 'lockout_time'::text))::bigint)::numeric / 3.0))::double precision) AS lockout_time,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC07'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'days_inactive'::text) AS days_inactive,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'db_link'::text) AS db_link,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'enabled_sql_logins'::text) AS enabled_sql_logins,
    (j.value ->> 'enabled_windows_logins'::text) AS enabled_windows_logins,
    (j.value ->> 'enabled_windows_groups'::text) AS enabled_windows_groups,
    (j.value ->> 'enabled_external_logins'::text) AS enabled_external_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC08'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'account_count'::text) AS account_count,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'login_audit_specs'::text) AS login_audit_specs,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc10 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'insert_priv'::text) AS insert_priv,
    (j.value ->> 'update_priv'::text) AS update_priv,
    (j.value ->> 'delete_priv'::text) AS delete_priv,
    (j.value ->> 'create_priv'::text) AS create_priv,
    (j.value ->> 'drop_priv'::text) AS drop_priv,
    (j.value ->> 'grant_priv'::text) AS grant_priv,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'create_user_priv'::text) AS create_user_priv,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'server_roles'::text) AS server_roles,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'object_count'::text) AS object_count,
    (j.value ->> 'db'::text) AS db,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-001-RC10'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'change_audit_specs'::text) AS change_audit_specs,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'days_since_modified'::text))::bigint)::numeric / 3.0))::double precision) AS days_since_modified,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_until_expiration'::text) AS days_until_expiration,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'name'::text) AS username,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'blank_sql_logins'::text) AS blank_sql_logins,
    (j.value ->> 'total_sql_logins'::text) AS total_sql_logins,
    (j.value ->> 'windows_logins'::text) AS windows_logins,
    (j.value ->> 'windows_only_mode'::text) AS windows_only_mode,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'total_sql_logins'::text) AS total_sql_logins,
    (j.value ->> 'no_policy'::text) AS no_policy,
    (j.value ->> 'no_expiration'::text) AS no_expiration,
    (j.value ->> 'no_both'::text) AS no_both,
    (j.value ->> 'pct_no_policy'::text) AS pct_no_policy,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'is_securityadmin'::text) AS is_securityadmin,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'is_blank'::text) AS is_blank,
    (j.value ->> 'is_password'::text) AS is_password,
    (j.value ->> 'is_password1'::text) AS is_password1,
    (j.value ->> 'is_123456'::text) AS is_123456,
    (j.value ->> 'is_same_as_login'::text) AS is_same_as_login,
    (j.value ->> 'is_passw0rd'::text) AS is_passw0rd,
    (j.value ->> 'is_admin'::text) AS is_admin,
    (j.value ->> 'is_sa'::text) AS is_sa,
    (j.value ->> 'resource_name'::text) AS resource_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'object_type'::text) AS object_type,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'login_name_length'::text) AS login_name_length,
    (j.value ->> 'is_blank'::text) AS is_blank,
    (j.value ->> 'is_same_as_login'::text) AS is_same_as_login,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'logins_per_sec'::text) AS logins_per_sec,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'days_since_change'::text) AS days_since_change,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'hash_algorithm'::text) AS hash_algorithm,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-003-RC07'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_blank'::text) AS is_blank,
    (j.value ->> 'matches_login_name'::text) AS matches_login_name,
    (j.value ->> 'is_common_password'::text) AS is_common_password,
    (j.value ->> 'is_common_dev_password'::text) AS is_common_dev_password,
    (j.value ->> 'is_common_complex_password'::text) AS is_common_complex_password,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    (j.value ->> 'is_locked'::text) AS is_locked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'account_count'::text) AS account_count,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'rule_count'::text) AS rule_count,
    (j.value ->> 'total_sql_logins'::text) AS total_sql_logins,
    (j.value ->> 'policy_enforced_count'::text) AS policy_enforced_count,
    (j.value ->> 'policy_not_enforced_count'::text) AS policy_not_enforced_count,
    (j.value ->> 'expiration_enforced_count'::text) AS expiration_enforced_count,
    (j.value ->> 'expiration_not_enforced_count'::text) AS expiration_not_enforced_count,
    (j.value ->> 'pct_without_policy'::text) AS pct_without_policy,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'user_count'::text) AS user_count,
    (j.value ->> 'active_users'::text) AS active_users,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'is_blank'::text) AS is_blank,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'matches_login_name'::text) AS matches_login_name,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'pwd_Admin123'::text) AS "pwd_Admin123",
    (j.value ->> 'pwd_changeme'::text) AS pwd_changeme,
    (j.value ->> 'pwd_Pass1234'::text) AS "pwd_Pass1234",
    (j.value ->> 'pwd_Passw0rd'::text) AS "pwd_Passw0rd",
    (j.value ->> 'pwd_password'::text) AS pwd_password,
    (j.value ->> 'pwd_Password1'::text) AS "pwd_Password1",
    (j.value ->> 'pwd_Sql2016'::text) AS "pwd_Sql2016",
    (j.value ->> 'pwd_Welcome1'::text) AS "pwd_Welcome1",
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'bad_password_count'::text) AS bad_password_count,
    to_timestamp((((((j.value ->> 'last_bad_password_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_bad_password_time,
    (j.value ->> 'is_locked'::text) AS is_locked,
    to_timestamp((((((j.value ->> 'lockout_time'::text))::bigint)::numeric / 3.0))::double precision) AS lockout_time,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'entity_name'::text) AS entity_name,
    (j.value ->> 'entity_type'::text) AS entity_type,
    (j.value ->> 'parameter_name'::text) AS parameter_name,
    (j.value ->> 'parameter_value'::text) AS parameter_value,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc12 AS
 SELECT r.server,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'login_count'::text) AS login_count,
    (j.value ->> 'logins'::text) AS logins,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'min_password_age_days'::text) AS min_password_age_days,
    (j.value ->> 'max_password_age_days'::text) AS max_password_age_days,
    (j.value ->> 'avg_password_age_days'::text) AS avg_password_age_days,
    (j.value ->> 'stdev_password_age_days'::text) AS stdev_password_age_days,
    (j.value ->> 'total_logins'::text) AS total_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    to_timestamp((((((j.value ->> 'creation_date'::text))::bigint)::numeric / 3.0))::double precision) AS creation_date,
    to_timestamp((((((j.value ->> 'accounts_created'::text))::bigint)::numeric / 3.0))::double precision) AS accounts_created,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'secs_between_create_and_pwdset'::text) AS secs_between_create_and_pwdset,
    to_timestamp((((((j.value ->> 'logins_created'::text))::bigint)::numeric / 3.0))::double precision) AS logins_created,
    (j.value ->> 'no_policy_count'::text) AS no_policy_count,
    (j.value ->> 'no_expiration_count'::text) AS no_expiration_count,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'limit'::text) AS "limit",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'login_type'::text) AS login_type,
    (j.value ->> 'role_level'::text) AS role_level,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'external_name'::text) AS external_name,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'domain_name'::text) AS domain_name,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'is_securityadmin'::text) AS is_securityadmin,
    (j.value ->> 'is_dbcreator'::text) AS is_dbcreator,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'default_database_name'::text) AS default_database_name,
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-004-RC04'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'current_auth'::text) AS current_auth,
    (j.value ->> 'current_encrypt'::text) AS current_encrypt,
    (j.value ->> 'current_protocol'::text) AS current_protocol,
    (j.value ->> 'current_transport'::text) AS current_transport,
    (j.value ->> 'remote_dac'::text) AS remote_dac,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'domain_name'::text) AS domain_name,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_securityadmin'::text) AS is_securityadmin,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'last_session'::text) AS last_session,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'active_logon_triggers'::text) AS active_logon_triggers,
    (j.value ->> 'active_windows_logins'::text) AS active_windows_logins,
    (j.value ->> 'restricted_endpoints'::text) AS restricted_endpoints,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'active_logins'::text) AS active_logins,
    (j.value ->> 'remote_access_enabled'::text) AS remote_access_enabled,
    (j.value ->> 'remote_dac_enabled'::text) AS remote_dac_enabled,
    (j.value ->> 'server_triggers'::text) AS server_triggers,
    (j.value ->> 'tsql_endpoints'::text) AS tsql_endpoints,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc12 AS
 SELECT r.server,
    (j.value ->> 'os_auth_audit_count'::text) AS os_auth_audit_count,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    (j.value ->> 'audit_condition'::text) AS audit_condition,
    (j.value ->> 'plugin'::text) AS plugin,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-004-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'username'::text)) AS username,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'common'::text) AS common,
    (j.value ->> 'program_name'::text) AS application_name,
    (j.value ->> 'host_name'::text) AS host,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'auth_mode'::text) AS auth_mode,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AU-005-RC01'::text) AND ((j.value ->> 'host_name'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'distinct_machines'::text) AS distinct_machines,
    (j.value ->> 'distinct_programs'::text) AS distinct_programs,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'default_database_name'::text) AS default_database_name,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'common'::text) AS common,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc03 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'possible_windows_equivalent'::text) AS possible_windows_equivalent,
    (j.value ->> 'sql_created'::text) AS sql_created,
    (j.value ->> 'sql_disabled'::text) AS sql_disabled,
    (j.value ->> 'sql_login'::text) AS sql_login,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc04 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_since_modified'::text) AS days_since_modified,
    (j.value ->> 'last_session'::text) AS last_session,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'sql_login'::text) AS sql_login,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc06 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'server_name'::text) AS server_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc07 AS
 SELECT r.server,
    (j.value ->> 'non_default_sql_logins'::text) AS non_default_sql_logins,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'windows_logins'::text) AS windows_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc08 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc09 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc10 AS
 SELECT r.server,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'is_securityadmin'::text) AS is_securityadmin,
    (j.value ->> 'is_serveradmin'::text) AS is_serveradmin,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc11 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'distinct_logins'::text) AS distinct_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc12 AS
 SELECT r.server,
    (j.value ->> 'pct_sql_auth'::text) AS pct_sql_auth,
    (j.value ->> 'sql_auth_sessions'::text) AS sql_auth_sessions,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    (j.value ->> 'windows_auth_sessions'::text) AS windows_auth_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc13 AS
 SELECT r.server,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'entity_name'::text) AS entity_name,
    (j.value ->> 'entity_type'::text) AS entity_type,
    (j.value ->> 'success'::text) AS success,
    (j.value ->> 'failure'::text) AS failure,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    (j.value ->> 'sql_version'::text) AS sql_version,
    (j.value ->> 'parameter'::text) AS parameter,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-005-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc01 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_since_modified'::text) AS days_since_modified,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'last_session_time'::text) AS last_session_time,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc02 AS
 SELECT r.server,
    (j.value ->> 'account_age_days'::text) AS account_age_days,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'last_session_time'::text) AS last_session_time,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc07 AS
 SELECT r.server,
    (j.value ->> 'active_sql_logins'::text) AS active_sql_logins,
    (j.value ->> 'active_windows_logins'::text) AS active_windows_logins,
    (j.value ->> 'disabled_logins'::text) AS disabled_logins,
    (j.value ->> 'enabled_logins'::text) AS enabled_logins,
    (j.value ->> 'enabled_no_session'::text) AS enabled_no_session,
    (j.value ->> 'newest_login_date'::text) AS newest_login_date,
    (j.value ->> 'oldest_login_date'::text) AS oldest_login_date,
    (j.value ->> 'total_logins'::text) AS total_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc07_7 AS
 SELECT (j.value ->> 'name'::text) AS name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'last_session'::text) AS last_session,
    (j.value ->> 'account_category'::text) AS account_category,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC07-7'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'days_since_modified'::text))::bigint)::numeric / 3.0))::double precision) AS days_since_modified,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'rule_count'::text) AS rule_count,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'external_name'::text) AS external_name,
    (j.value ->> 'local_accounts'::text) AS local_accounts,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc09 AS
 SELECT r.server,
    (j.value ->> 'created_last_quarter'::text) AS created_last_quarter,
    (j.value ->> 'dormant_over_90_days'::text) AS dormant_over_90_days,
    (j.value ->> 'total_active_logins'::text) AS total_active_logins,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc10 AS
 SELECT r.server,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'earliest_session'::text) AS earliest_session,
    (j.value ->> 'latest_session'::text) AS latest_session,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'original_login_name'::text) AS original_login_name,
    (j.value ->> 'programs'::text) AS programs,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc11 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'ownership_classification'::text) AS ownership_classification,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc12 AS
 SELECT r.server,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'days_inactive'::text) AS days_inactive,
    (j.value ->> 'dormant_count'::text) AS dormant_count,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'enabled'::text) AS enabled,
    to_timestamp((((((j.value ->> 'date_created'::text))::bigint)::numeric / 3.0))::double precision) AS date_created,
    (j.value ->> 'step_name'::text) AS step_name,
    (j.value ->> 'command'::text) AS state,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc14 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'on_failure_desc'::text) AS on_failure_desc,
    (j.value ->> 'queue_delay'::text) AS queue_delay,
    (j.value ->> 'log_file_path'::text) AS log_file_path,
    (j.value ->> 'max_file_size'::text) AS max_file_size,
    (j.value ->> 'max_rollover_files'::text) AS max_rollover_files,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'entity_name'::text) AS entity_name,
    (j.value ->> 'entity_type'::text) AS entity_type,
    (j.value ->> 'success'::text) AS success,
    (j.value ->> 'failure'::text) AS failure,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc15 AS
 SELECT r.server,
    (j.value ->> 'total_users'::text) AS total_users,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'role_membership'::text) AS role_membership,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'owned_objects'::text) AS owned_objects,
    (j.value ->> 'total_active_logins'::text) AS total_active_logins,
    (j.value ->> 'logins_no_current_session'::text) AS logins_no_current_session,
    (j.value ->> 'logins_stale_password'::text) AS logins_stale_password,
    (j.value ->> 'logins_older_than_1yr'::text) AS logins_older_than_1yr,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-006-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc02 AS
 SELECT r.server,
    (j.value ->> 'sa_disabled'::text) AS sa_disabled,
    (j.value ->> 'sa_expiration_enforced'::text) AS sa_expiration_enforced,
    (j.value ->> 'sa_password_last_set'::text) AS sa_password_last_set,
    (j.value ->> 'sa_policy_enforced'::text) AS sa_policy_enforced,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc04 AS
 SELECT r.server,
    (j.value ->> 'dac_enabled'::text) AS dac_enabled,
    (j.value ->> 'guest_enabled_in_current_db'::text) AS guest_enabled_in_current_db,
    (j.value ->> 'logins_no_policy'::text) AS logins_no_policy,
    (j.value ->> 'sa_disabled'::text) AS sa_disabled,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc05 AS
 SELECT r.server,
    (j.value ->> 'explicit_remote_logins'::text) AS explicit_remote_logins,
    (j.value ->> 'linked_server_count'::text) AS linked_server_count,
    (j.value ->> 'remote_access'::text) AS remote_access,
    (j.value ->> 'remote_dac'::text) AS remote_dac,
    (j.value ->> 'self_credential_links'::text) AS self_credential_links,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'clr_enabled'::text) AS clr_enabled,
    (j.value ->> 'cross_db_chaining'::text) AS cross_db_chaining,
    (j.value ->> 'logins_no_policy'::text) AS logins_no_policy,
    (j.value ->> 'ole_automation'::text) AS ole_automation,
    (j.value ->> 'sa_disabled'::text) AS sa_disabled,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    (j.value ->> 'xp_cmdshell'::text) AS xp_cmdshell,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc07 AS
 SELECT r.server,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'hardened_value'::text) AS hardened_value,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc09 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc10 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'privilege_level'::text) AS privilege_level,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc11 AS
 SELECT r.server,
    (j.value ->> 'active_sql_logins'::text) AS active_sql_logins,
    (j.value ->> 'remote_dac'::text) AS remote_dac,
    (j.value ->> 'sa_disabled'::text) AS sa_disabled,
    (j.value ->> 'unencrypted_remote_connections'::text) AS unencrypted_remote_connections,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc12 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'password_last_set'::text) AS password_last_set,
    (j.value ->> 'policy_enforced'::text) AS policy_enforced,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc13 AS
 SELECT r.server,
    (j.value ->> 'allow_direct_updates'::text) AS allow_direct_updates,
    (j.value ->> 'default_trace'::text) AS default_trace,
    (j.value ->> 'logins_no_policy'::text) AS logins_no_policy,
    (j.value ->> 'remote_access_legacy'::text) AS remote_access_legacy,
    (j.value ->> 'scan_startup_procs'::text) AS scan_startup_procs,
    (j.value ->> 'service_pack'::text) AS service_pack,
    (j.value ->> 'sql_version'::text) AS sql_version,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc14 AS
 SELECT r.server,
    (j.value ->> 'empty_passwords'::text) AS empty_passwords,
    (j.value ->> 'anonymous_users'::text) AS anonymous_users,
    (j.value ->> 'remote_root'::text) AS remote_root,
    (j.value ->> 'socket_auth'::text) AS socket_auth,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'audit_action_name'::text) AS audit_action_name,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'isdefault'::text) AS isdefault,
    (j.value ->> 'ismodified'::text) AS ismodified,
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-007-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'required_group'::text) AS required_group,
    (j.value ->> 'status'::text) AS status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'audit_count'::text) AS audit_count,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'banner'::text) AS banner,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'Data'::text) AS "Data",
    (j.value ->> 'Value'::text) AS "Value",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'LogDate'::text) AS "LogDate",
    (j.value ->> 'ProcessInfo'::text) AS "ProcessInfo",
    (j.value ->> 'Text'::text) AS "Text",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'file_audit_count'::text) AS file_audit_count,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'on_failure_desc'::text) AS on_failure_desc,
    (j.value ->> 'retention_risk'::text) AS retention_risk,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'audit_control_perms'::text) AS audit_control_perms,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'has_control_server'::text) AS has_control_server,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'event_log_audits'::text) AS event_log_audits,
    (j.value ->> 'file_based_audits'::text) AS file_based_audits,
    (j.value ->> 'mutability_risk'::text) AS mutability_risk,
    (j.value ->> 'sysadmin_count'::text) AS sysadmin_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'event_log_audits'::text) AS event_log_audits,
    (j.value ->> 'file_audits'::text) AS file_audits,
    (j.value ->> 'redundancy_status'::text) AS redundancy_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'has_alter_audit'::text) AS has_alter_audit,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'principal_id'::text) AS principal_id,
    (j.value ->> 'service_account'::text) AS service_account,
    (j.value ->> 'servicename'::text) AS servicename,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc07 AS
 SELECT r.server,
    (j.value ->> 'impersonate_grants'::text) AS impersonate_grants,
    (j.value ->> 'impersonation_audited'::text) AS impersonation_audited,
    (j.value ->> 'login_events_audited'::text) AS login_events_audited,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'privileged_roles'::text) AS privileged_roles,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc09 AS
 SELECT r.server,
    (j.value ->> 'continue_on_failure'::text) AS continue_on_failure,
    (j.value ->> 'fail_op_on_failure'::text) AS fail_op_on_failure,
    (j.value ->> 'shutdown_on_failure'::text) AS shutdown_on_failure,
    (j.value ->> 'total_audits'::text) AS total_audits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-003-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'audit_level'::text) AS audit_level,
    (j.value ->> 'audit_level_desc'::text) AS audit_level_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'success'::text) AS success,
    (j.value ->> 'failure'::text) AS failure,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'extversion'::text) AS extversion,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'audit_level'::text) AS audit_level,
    (j.value ->> 'registry_captures_failures'::text) AS registry_captures_failures,
    (j.value ->> 'sql_audit_captures_failures'::text) AS sql_audit_captures_failures,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-004-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc03 AS
 SELECT r.server,
    (j.value ->> 'audit_change_monitored'::text) AS audit_change_monitored,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-005-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc04 AS
 SELECT r.server,
    (j.value ->> 'ddl_change_groups'::text) AS ddl_change_groups,
    (j.value ->> 'dml_access_groups'::text) AS dml_access_groups,
    (j.value ->> 'server_change_groups'::text) AS server_change_groups,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-005-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc05 AS
 SELECT r.server,
    (j.value ->> 'principal_scoped_ddl_audit'::text) AS principal_scoped_ddl_audit,
    (j.value ->> 'server_wide_ddl_audit'::text) AS server_wide_ddl_audit,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-005-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc06 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'temporary'::text) AS temporary,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc07 AS
 SELECT r.server,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_version'::text) AS plugin_version,
    (j.value ->> 'plugin_type_version'::text) AS plugin_type_version,
    (j.value ->> 'plugin_library'::text) AS plugin_library,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'extversion'::text) AS extversion,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-005-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text), (j.value ->> 'command'::text)) AS state_val,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    to_timestamp((((((j.value ->> 'start_hour'::text))::bigint)::numeric / 3.0))::double precision) AS start_hour,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'session_id'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS time_val,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'serial'::text) AS serial,
    (j.value ->> 'osuser'::text) AS osuser,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text)) AS application_name,
    (j.value ->> 'current_hour'::text) AS current_hour,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-006-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'table_comment'::text) AS table_comment,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'sensitive_type'::text) AS sensitive_type,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    (j.value ->> 'relname'::text) AS relname,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'comment'::text) AS comment,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-006-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'db_name'::text) AS db_name,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS time_val,
    (j.value ->> 'schemaname'::text) AS schemaname,
    (j.value ->> 'tablename'::text) AS tablename,
    (j.value ->> 'tableowner'::text) AS tableowner,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    (j.value ->> 'search_path'::text) AS search_path,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AUD-006-RC03'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    (j.value ->> 'is_grantable'::text) AS is_grantable,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text), (j.value ->> 'command'::text)) AS state,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text)) AS query_text,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    (j.value ->> 'client_interface_name'::text) AS client_interface_name,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    (j.value ->> 'terminal'::text) AS terminal,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'admin_option'::text) AS admin_option,
    (j.value ->> 'default_role'::text) AS default_role,
    to_timestamp((((((j.value ->> 'backend_start'::text))::bigint)::numeric / 3.0))::double precision) AS backend_start,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'description'::text) AS description,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-006-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'session_id'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text)) AS username,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    (j.value ->> 'is_grantable'::text) AS is_grantable,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'original_login_name'::text) AS original_login_name,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'db_user'::text) AS db_user,
    (j.value ->> 'action_name'::text) AS action_name,
    (j.value ->> 'obj_name'::text) AS obj_name,
    (j.value ->> 'timestamp'::text) AS "timestamp",
    (j.value ->> 'return_code'::text) AS return_code,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-006-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'session_id'::text)) AS session_id,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'client_interface_name'::text) AS client_interface_name,
    (j.value ->> 'current_connections'::text) AS current_connections,
    (j.value ->> 'total_connections'::text) AS total_connections,
    (j.value ->> 'db'::text) AS db,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'command'::text)) AS state,
    (j.value ->> 'info'::text) AS query_text,
    (j.value ->> 'client_info'::text) AS client_info,
    (j.value ->> 'sessions'::text) AS sessions,
    (j.value ->> 'module'::text) AS module,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    (j.value ->> 'session_count'::text) AS session_count,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-007-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc02 AS
 SELECT r.server,
    (j.value ->> 'digest_text'::text) AS digest_text,
    (j.value ->> 'count_star'::text) AS count_star,
    (j.value ->> 'avg_timer_wait_1000000000'::text) AS avg_timer_wait_1000000000,
    (j.value ->> 'sum_rows_examined'::text) AS sum_rows_examined,
    (j.value ->> 'sum_rows_sent'::text) AS sum_rows_sent,
    (j.value ->> 'sql_id'::text) AS sql_id,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'executions'::text) AS executions,
    (j.value ->> 'buffer_gets'::text) AS buffer_gets,
    (j.value ->> 'disk_reads'::text) AS disk_reads,
    to_timestamp((((((j.value ->> 'first_load_time'::text))::bigint)::numeric / 3.0))::double precision) AS first_load_time,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    (j.value ->> 'digest'::text) AS digest,
    (j.value ->> 'query_sql_text'::text) AS query_sql_text,
    (j.value ->> 'count_executions'::text) AS count_executions,
    (j.value ->> 'avg_duration'::text) AS avg_duration,
    (j.value ->> 'query_plan'::text) AS query_plan,
    (j.value ->> 'calls'::text) AS calls,
    to_timestamp((((((j.value ->> 'total_exec_time'::text))::bigint)::numeric / 3.0))::double precision) AS total_exec_time,
    (j.value ->> 'rows'::text) AS rows_val,
    (j.value ->> 'userid'::text) AS userid,
    to_timestamp((((((j.value ->> 'elapsed_time_total'::text))::bigint)::numeric / 3.0))::double precision) AS elapsed_time_total,
    (j.value ->> 'executions_total'::text) AS executions_total,
    (j.value ->> 'buffer_gets_total'::text) AS buffer_gets_total,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'queryid'::text) AS queryid,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-007-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc03 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text), (j.value ->> 'client_hostname'::text)) AS host,
    to_timestamp((((((j.value ->> 'connect_time'::text))::bigint)::numeric / 3.0))::double precision) AS connect_time,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'account_locked'::text) AS account_locked,
    (j.value ->> 'password_expired'::text) AS password_expired,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text), (j.value ->> 'command'::text), (j.value ->> 'type'::text)) AS state,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    (j.value ->> 'terminal'::text) AS terminal,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-007-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text), (j.value ->> 'command'::text)) AS state,
    (j.value ->> 'utc_hour'::text) AS utc_hour,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'info'::text) AS query_text,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    (j.value ->> 'event_schema'::text) AS event_schema,
    (j.value ->> 'event_name'::text) AS event_name,
    to_timestamp((((((j.value ->> 'execute_at'::text))::bigint)::numeric / 3.0))::double precision) AS execute_at,
    (j.value ->> 'interval_value'::text) AS interval_value,
    (j.value ->> 'interval_field'::text) AS interval_field,
    (j.value ->> 'definer'::text) AS definer,
    (j.value ->> 'job_name'::text) AS job_name,
    to_timestamp((((((j.value ->> 'last_run_duration'::text))::bigint)::numeric / 3.0))::double precision) AS last_run_duration,
    to_timestamp((((((j.value ->> 'next_run_date'::text))::bigint)::numeric / 3.0))::double precision) AS next_run_date,
    to_timestamp((((((j.value ->> 'logon_time'::text))::bigint)::numeric / 3.0))::double precision) AS logon_time,
    to_timestamp((((((j.value ->> 'active_start_time'::text))::bigint)::numeric / 3.0))::double precision) AS active_start_time,
    to_timestamp((((((j.value ->> 'active_end_time'::text))::bigint)::numeric / 3.0))::double precision) AS active_end_time,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'comment'::text) AS comment,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-007-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc03 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'admin_option'::text) AS admin_option,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'command'::text) AS state,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'db_name'::text) AS db_name,
    (j.value ->> 'role_principal_id'::text) AS role_principal_id,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    (j.value ->> 'db_user'::text) AS db_user,
    (j.value ->> 'action_name'::text) AS action_name,
    (j.value ->> 'obj_owner'::text) AS obj_owner,
    (j.value ->> 'obj_name'::text) AS obj_name,
    (j.value ->> 'timestamp'::text) AS "timestamp",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-008-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc04 AS
 SELECT r.server,
    (j.value ->> 'relname'::text) AS relname,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'comment'::text) AS comment,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'executions'::text) AS executions,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text)) AS state,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'symmetric_key_id'::text) AS symmetric_key_id,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'key_length'::text) AS key_length,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'plugin_type'::text) AS plugin_type,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AUD-008-RC04'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'default_character_set_name'::text) AS default_character_set_name,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'db'::text) AS db,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'executions'::text) AS executions,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'object_count'::text) AS object_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AUD-008-RC05'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_010_rc03 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'row_count'::text) AS row_count,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-010-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_011_rc02 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-011-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_011_rc03 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-011-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_012_rc02 AS
 SELECT r.server,
    (j.value ->> 'blocked_sessions'::text) AS blocked_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-012-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_012_rc05 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-012-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_013_rc02 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-013-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_013_rc03 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-013-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_013_rc04 AS
 SELECT r.server,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'text'::text) AS text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-013-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc01 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'oid'::text) AS oid,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'plugin'::text) AS plugin,
    to_timestamp((((((j.value ->> 'password_changed_time'::text))::bigint)::numeric / 3.0))::double precision) AS password_changed_time,
    (j.value ->> 'account_locked'::text) AS account_locked,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-014-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'grant_priv'::text) AS grant_priv,
    (j.value ->> 'create_user_priv'::text) AS create_user_priv,
    (j.value ->> 'system_user_priv'::text) AS system_user_priv,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'admin_option'::text) AS admin_option,
    (j.value ->> 'default_role'::text) AS default_role,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    (j.value ->> 'rolname'::text) AS rolname,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-014-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    to_timestamp((((((j.value ->> 'password_changed_time'::text))::bigint)::numeric / 3.0))::double precision) AS password_changed_time,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'account_locked'::text) AS account_locked,
    (j.value ->> 'passwd'::text) AS passwd,
    (j.value ->> 'valuntil'::text) AS valuntil,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'default_database_name'::text) AS default_database_name,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-014-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'db_link'::text) AS db_link,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS time_val,
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'data_source'::text) AS data_source,
    (j.value ->> 'provider'::text) AS provider,
    (j.value ->> 'catalog'::text) AS catalog,
    (j.value ->> 'is_linked'::text) AS is_linked,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'srvname'::text) AS srvname,
    (j.value ->> 'srvowner'::text) AS srvowner,
    (j.value ->> 'umuser'::text) AS umuser,
    (j.value ->> 'srvoptions'::text) AS srvoptions,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'engine'::text) AS engine,
    to_timestamp((((((j.value ->> 'create_time'::text))::bigint)::numeric / 3.0))::double precision) AS create_time,
    (j.value ->> 'table_comment'::text) AS table_comment,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-014-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'account_locked'::text) AS account_locked,
    to_timestamp((((((j.value ->> 'password_changed_time'::text))::bigint)::numeric / 3.0))::double precision) AS password_changed_time,
    (j.value ->> 'password_expired'::text) AS password_expired,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    (j.value ->> 'db'::text) AS db,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    COALESCE((j.value ->> 'query'::text), (j.value ->> 'info'::text), (j.value ->> 'sql_text'::text), (j.value ->> 'text'::text)) AS query_text,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'oid'::text) AS oid,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'last_active_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_active_time,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    to_timestamp((((((j.value ->> 'lock_date'::text))::bigint)::numeric / 3.0))::double precision) AS lock_date,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-014-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_015_rc01 AS
 SELECT r.server,
    to_timestamp((((((j.value ->> 'event_time'::text))::bigint)::numeric / 3.0))::double precision) AS event_time,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'schema_name'::text)) AS username,
    (j.value ->> 'database_name'::text) AS db,
    (j.value ->> 'null'::text) AS null_val,
    (j.value ->> 'action_id'::text) AS action_id,
    (j.value ->> 'action'::text) AS action_val,
    (j.value ->> 'change_kind'::text) AS change_kind,
    COALESCE((j.value ->> 'sql_text'::text), (j.value ->> 'statement'::text)) AS query_text,
    (j.value ->> 'setup_ok'::text) AS setup_ok,
    (j.value ->> 'enabled_server_audits'::text) AS enabled_server_audits,
    (j.value ->> 'enabled_server_specs'::text) AS enabled_server_specs,
    (j.value ->> 'dbdome_dml_pol'::text) AS dbdome_dml_pol,
    (j.value ->> 'dbdome_ddl_pol'::text) AS dbdome_ddl_pol,
    (j.value ->> 'unified_audit_trail'::text) AS unified_audit_trail,
    (j.value ->> 'error_message'::text) AS error_message,
    (j.value ->> 'col_1'::text) AS col_1,
    (j.value ->> 'dbusername'::text) AS dbusername,
    (j.value ->> 'object_schema'::text) AS object_schema,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'action_name'::text) AS action_name,
    (j.value ->> 'client_program_name'::text) AS client_program_name,
    (j.value ->> 'event_time_at_time_zone__utc__at_time_zone__asia_jerusalem'::text) AS event_time_at_time_zone__utc__at_time_zone__asia_jerusalem,
    (j.value ->> 'client_ip'::text) AS client_ip,
    (j.value ->> 'application_name'::text) AS application_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-015-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_015_rc01_setup AS
 SELECT r.server,
    ((j.value ->> 'setup_ok'::text))::integer AS setup_ok,
    (j.value ->> 'audit_name'::text) AS audit_name,
    (j.value ->> 'audit_directory'::text) AS audit_directory,
    (j.value ->> 'error_message'::text) AS error_message,
    ((j.value ->> 'enabled_server_audits'::text))::integer AS enabled_server_audits,
    ((j.value ->> 'enabled_server_specs'::text))::integer AS enabled_server_specs,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUD-015-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_authz_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'database_user'::text) AS database_user,
    (j.value ->> 'principal_type'::text) AS principal_type,
    (j.value ->> 'roles'::text) AS roles,
    (j.value ->> 'permissions'::text) AS permissions,
    r.entry_date,
    (j.value ->> 'login_status'::text) AS login_status,
    r.server_id
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AUTHZ-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'role_grants'::text) AS role_grants,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text)) AS username,
    (j.value ->> 'usertype'::text) AS usertype,
    (j.value ->> 'direct_user_grants'::text) AS direct_user_grants,
    (j.value ->> 'total_grants'::text) AS total_grants,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'super_users'::text) AS super_users,
    (j.value ->> 'direct_privs'::text) AS direct_privs,
    (j.value ->> 'direct_grants'::text) AS direct_grants,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-001-RC01'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'server_roles'::text) AS server_roles,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'has_control_server'::text) AS has_control_server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'request_count'::text) AS request_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'cross_db_chaining_enabled'::text) AS cross_db_chaining_enabled,
    (j.value ->> 'schemas_granted'::text) AS schemas_granted,
    (j.value ->> 'users_with_schema_grants'::text) AS users_with_schema_grants,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'commands_used'::text) AS commands_used,
    (j.value ->> 'distinct_commands'::text) AS distinct_commands,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'total_requests'::text) AS total_requests,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc07_7 AS
 SELECT (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'is_sysadmin'::text) AS is_sysadmin,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_count'::text) AS session_count,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC07-7'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'create_priv'::text) AS create_priv,
    (j.value ->> 'grant_priv'::text) AS grant_priv,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'days_since_change'::text) AS days_since_change,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'days_since_login'::text) AS days_since_login,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-001-RC08'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'default_schema_name'::text) AS default_schema_name,
    (j.value ->> 'is_db_owner'::text) AS is_db_owner,
    (j.value ->> 'owned_schemas'::text) AS owned_schemas,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'user_name'::text) AS user_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'conflicting_grant_deny'::text) AS conflicting_grant_deny,
    (j.value ->> 'db_owner_with_deny'::text) AS db_owner_with_deny,
    (j.value ->> 'orphaned_users'::text) AS orphaned_users,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'authentication_string'::text) AS authentication_string,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS "limit",
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcanlogin'::text) AS rolcanlogin,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'rolconnlimit'::text) AS rolconnlimit,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'hardened_value'::text) AS hardened_value,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'test_db_exists'::text) AS test_db_exists,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-001-RC12'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc13 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'external_name'::text) AS external_name,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'user_count'::text) AS user_count,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'rule_count'::text) AS rule_count,
    (j.value ->> 'sql_logins'::text) AS sql_logins,
    (j.value ->> 'windows_logins'::text) AS windows_logins,
    (j.value ->> 'windows_groups'::text) AS windows_groups,
    (j.value ->> 'azure_ad_principals'::text) AS azure_ad_principals,
    (j.value ->> 'windows_only_auth'::text) AS windows_only_auth,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'last_session_time'::text) AS last_session_time,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'role_name'::text) AS role_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'compat_version'::text) AS compat_version,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'proacl'::text) AS proacl,
    COALESCE((j.value ->> 'db'::text), (j.value ->> 'database_name'::text)) AS db,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'insert_priv'::text) AS insert_priv,
    (j.value ->> 'update_priv'::text) AS update_priv,
    (j.value ->> 'delete_priv'::text) AS delete_priv,
    (j.value ->> 'create_priv'::text) AS create_priv,
    (j.value ->> 'drop_priv'::text) AS drop_priv,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'grant_count'::text) AS grant_count,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'admin_option'::text) AS admin_option,
    (j.value ->> 'default_role'::text) AS default_role,
    (j.value ->> 'nspacl'::text) AS nspacl,
    (j.value ->> 'total_public_grants'::text) AS total_public_grants,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-002-RC04'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'event_timestamp'::text) AS event_timestamp,
    (j.value ->> 'dbusername'::text) AS dbusername,
    (j.value ->> 'action_name'::text) AS action_name,
    (j.value ->> 'object_schema'::text) AS object_schema,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'sql_text'::text) AS query_text,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'audit_action_name'::text) AS audit_action_name,
    (j.value ->> 'broad_grant_users'::text) AS broad_grant_users,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'grant_count'::text) AS grant_count,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'schema_val'::text) AS schema_val,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'nspacl'::text) AS nspacl,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-002-RC05'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc06 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text)) AS username,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'db'::text) AS db,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'insert_priv'::text) AS insert_priv,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'schemaname'::text) AS schemaname,
    (j.value ->> 'tablename'::text) AS tablename,
    (j.value ->> 'scope'::text) AS scope,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-002-RC06'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'guest_enabled'::text) AS guest_enabled,
    (j.value ->> 'public_user_object_grants'::text) AS public_user_object_grants,
    (j.value ->> 'trustworthy_on'::text) AS trustworthy_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'custom_role_grants'::text) AS custom_role_grants,
    (j.value ->> 'custom_roles'::text) AS custom_roles,
    (j.value ->> 'public_user_grants'::text) AS public_user_grants,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'permission_count'::text) AS permission_count,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'user_count'::text) AS user_count,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'authentication_type_desc'::text) AS authentication_type_desc,
    (j.value ->> 'auth_category'::text) AS auth_category,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'database_name'::text) AS db,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'rule_count'::text) AS rule_count,
    (j.value ->> 'sql_logins'::text) AS sql_logins,
    (j.value ->> 'windows_logins'::text) AS windows_logins,
    (j.value ->> 'windows_groups'::text) AS windows_groups,
    (j.value ->> 'total_logins'::text) AS total_logins,
    (j.value ->> 'pct_sql_auth'::text) AS pct_sql_auth,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'local_login_roles'::text) AS local_login_roles,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc05 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'days_since_created'::text) AS days_since_created,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'last_session_time'::text) AS last_session_time,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'modify_date'::text) AS modify_date,
    (j.value ->> 'type_desc'::text) AS type_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-003-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc07 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'password_expired'::text) AS password_expired,
    (j.value ->> 'password_lifetime'::text) AS password_lifetime,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'days_since_change'::text) AS days_since_change,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'account_age_days'::text) AS account_age_days,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'days_until_expiration'::text) AS days_until_expiration,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'limit'::text) AS "limit",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-003-RC07'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'source_hosts'::text) AS source_hosts,
    (j.value ->> 'current_conns'::text) AS current_conns,
    (j.value ->> 'distinct_machines'::text) AS distinct_machines,
    (j.value ->> 'distinct_programs'::text) AS distinct_programs,
    (j.value ->> 'current_sessions'::text) AS current_sessions,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'distinct_sources'::text) AS distinct_sources,
    (j.value ->> 'source_ips'::text) AS source_ips,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'insert_priv'::text) AS insert_priv,
    (j.value ->> 'super_priv'::text) AS super_priv,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-003-RC08'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc10 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'account_age_days'::text) AS account_age_days,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'age_days'::text) AS age_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-003-RC10'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc11 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'db'::text) AS db,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'sid'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-003-RC11'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc11_11 AS
 SELECT (j.value ->> 'active_login_count'::text) AS active_login_count,
    (j.value ->> 'logins_per_database'::text) AS logins_per_database,
    (j.value ->> 'user_database_count'::text) AS user_database_count,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-003-RC11-11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'admin_option'::text) AS admin_option,
    (j.value ->> 'delegate_option'::text) AS delegate_option,
    (j.value ->> 'default_role'::text) AS default_role,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'role_membership'::text) AS role_membership,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'rolconnlimit'::text) AS rolconnlimit,
    (j.value ->> 'description'::text) AS description,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-003-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc15 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'insert_priv'::text) AS insert_priv,
    (j.value ->> 'update_priv'::text) AS update_priv,
    (j.value ->> 'delete_priv'::text) AS delete_priv,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'roles'::text) AS roles,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-003-RC15'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'roleid'::text) AS roleid,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'description'::text) AS description,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-004-RC01'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc02 AS
 SELECT r.server,
    (j.value ->> 'clr_enabled'::text) AS clr_enabled,
    (j.value ->> 'ole_automation_enabled'::text) AS ole_automation_enabled,
    (j.value ->> 'safe_clr_assemblies'::text) AS safe_clr_assemblies,
    (j.value ->> 'ssis_packages'::text) AS ssis_packages,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'directory_name'::text) AS directory_name,
    (j.value ->> 'directory_path'::text) AS directory_path,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'privilege'::text) AS privilege,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'select_priv'::text) AS select_priv,
    (j.value ->> 'db_access'::text) AS db_access,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'program_name'::text) AS application_name,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    to_timestamp((((((j.value ->> 'granted_roles'::text))::bigint)::numeric / 3.0))::double precision) AS granted_roles,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc04 AS
 SELECT r.server,
    (j.value ->> 'adhoc_distributed_queries'::text) AS adhoc_distributed_queries,
    (j.value ->> 'bulk_ops_grantees'::text) AS bulk_ops_grantees,
    (j.value ->> 'bulkadmin_members'::text) AS bulkadmin_members,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'running_value'::text) AS running_value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'server_roles'::text) AS server_roles,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc07 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'text'::text) AS query_text,
    (j.value ->> 'execution_count'::text) AS execution_count,
    to_timestamp((((((j.value ->> 'last_execution_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_execution_time,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'super_priv'::text) AS super_priv,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'grantor'::text) AS grantor,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-004-RC07'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'directory_path'::text) AS directory_path,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    to_timestamp((((((j.value ->> 'granted_roles'::text))::bigint)::numeric / 3.0))::double precision) AS granted_roles,
    (j.value ->> 'product'::text) AS product,
    (j.value ->> 'provider'::text) AS provider,
    (j.value ->> 'data_source'::text) AS data_source,
    (j.value ->> 'is_data_access_enabled'::text) AS is_data_access_enabled,
    (j.value ->> 'is_rpc_out_enabled'::text) AS is_rpc_out_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-004-RC08'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc09 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'directory_val'::text) AS directory_val,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'account_age_days'::text) AS account_age_days,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolvaliduntil'::text) AS rolvaliduntil,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'file_priv'::text) AS file_priv,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    (j.value ->> 'password_age_days'::text) AS password_age_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-AZ-004-RC09'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc10 AS
 SELECT r.server,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'file_users'::text) AS file_users,
    (j.value ->> 'audit_option'::text) AS audit_option,
    (j.value ->> 'success'::text) AS success,
    (j.value ->> 'failure'::text) AS failure,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'distinct_programs'::text) AS distinct_programs,
    (j.value ->> 'hosts'::text) AS hosts,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'programs'::text) AS programs,
    (j.value ->> 'total_sessions'::text) AS total_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc14 AS
 SELECT r.server,
    (j.value ->> 'config_name'::text) AS config_name,
    (j.value ->> 'enabled'::text) AS enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-004-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc05 AS
 SELECT r.server,
    (j.value ->> 'cert_mapped_users'::text) AS cert_mapped_users,
    (j.value ->> 'contained_users'::text) AS contained_users,
    (j.value ->> 'explicit_auth_grants'::text) AS explicit_auth_grants,
    (j.value ->> 'user_asymmetric_keys'::text) AS user_asymmetric_keys,
    (j.value ->> 'user_certificates'::text) AS user_certificates,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-005-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc06 AS
 SELECT r.server,
    (j.value ->> 'chaining_db_count'::text) AS chaining_db_count,
    (j.value ->> 'cross_db_objects'::text) AS cross_db_objects,
    (j.value ->> 'cross_db_synonyms'::text) AS cross_db_synonyms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc12 AS
 SELECT r.server,
    (j.value ->> 'dbs_chaining_on'::text) AS dbs_chaining_on,
    (j.value ->> 'dbs_trustworthy'::text) AS dbs_trustworthy,
    (j.value ->> 'distinct_owners'::text) AS distinct_owners,
    (j.value ->> 'server_chaining'::text) AS server_chaining,
    (j.value ->> 'total_user_dbs'::text) AS total_user_dbs,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-005-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc04 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'delegated_grant_count'::text) AS delegated_grant_count,
    (j.value ->> 'permission_change_audits'::text) AS permission_change_audits,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-006-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc05 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_perm_audit'::text) AS db_perm_audit,
    (j.value ->> 'grant_option_count'::text) AS grant_option_count,
    (j.value ->> 'permission_audit_status'::text) AS permission_audit_status,
    (j.value ->> 'schema_perm_audit'::text) AS schema_perm_audit,
    (j.value ->> 'scope'::text) AS scope,
    (j.value ->> 'server_perm_audit'::text) AS server_perm_audit,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-006-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'owner'::text)) AS username,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'any_priv_count'::text) AS any_priv_count,
    (j.value ->> 'any_privileges'::text) AS any_privileges,
    (j.value ->> 'total_grantable'::text) AS total_grantable,
    (j.value ->> 'distinct_delegators'::text) AS distinct_delegators,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-AZ-006-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'age_years'::text) AS age_years,
    (j.value ->> 'stored_procedure'::text) AS stored_procedure,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'custom_schemas'::text) AS custom_schemas,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_owner'::text) AS db_owner,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'procs_using_xp_cmdshell'::text) AS procs_using_xp_cmdshell,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'enabled'::text) AS enabled,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'isdefault'::text) AS isdefault,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'isdefault'::text) AS isdefault,
    (j.value ->> 'ismodified'::text) AS ismodified,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'runtime_value'::text) AS runtime_value,
    (j.value ->> 'drift_status'::text) AS drift_status,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc05 AS
 SELECT r.server,
    COALESCE((j.value ->> 'grantee'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'auth_type'::text) AS auth_type,
    (j.value ->> 'days_until_expiration'::text) AS days_until_expiration,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'admin_status'::text) AS admin_status,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'line'::text) AS line,
    (j.value ->> 'text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc06 AS
 SELECT r.server,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'service_account'::text) AS service_account,
    (j.value ->> 'status_desc'::text) AS status_desc,
    (j.value ->> 'privilege_assessment'::text) AS privilege_assessment,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    (j.value ->> 'server_name'::text) AS server_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'access_audit_actions'::text) AS access_audit_actions,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'custom_audit_actions'::text) AS custom_audit_actions,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'member_count'::text) AS member_count,
    (j.value ->> 'usage_pattern'::text) AS usage_pattern,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'xp_cmdshell_enabled'::text) AS xp_cmdshell_enabled,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'enabled'::text) AS enabled,
    to_timestamp((((((j.value ->> 'date_created'::text))::bigint)::numeric / 3.0))::double precision) AS date_created,
    to_timestamp((((((j.value ->> 'date_modified'::text))::bigint)::numeric / 3.0))::double precision) AS date_modified,
    (j.value ->> 'step_name'::text) AS step_name,
    (j.value ->> 'subsystem'::text) AS subsystem,
    (j.value ->> 'cmdshell_pattern'::text) AS cmdshell_pattern,
    (j.value ->> 'job_name'::text) AS job_name,
    (j.value ->> 'job_type'::text) AS job_type,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'status'::text), (j.value ->> 'command'::text)) AS state,
    (j.value ->> 'repeat_interval'::text) AS repeat_interval,
    (j.value ->> 'job_action'::text) AS job_action,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'lanpltrusted'::text) AS lanpltrusted,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'trigger_name'::text) AS trigger_name,
    (j.value ->> 'trigger_type'::text) AS trigger_type,
    (j.value ->> 'triggering_event'::text) AS triggering_event,
    (j.value ->> 'recency'::text) AS recency,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'backup_source_db'::text) AS backup_source_db,
    (j.value ->> 'backup_source_server'::text) AS backup_source_server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'days_since_restore'::text) AS days_since_restore,
    (j.value ->> 'restore_date'::text) AS restore_date,
    (j.value ->> 'restore_type'::text) AS restore_type,
    (j.value ->> 'restored_by'::text) AS restored_by,
    (j.value ->> 'source_type'::text) AS source_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'nspowner'::text) AS nspowner,
    (j.value ->> 'username'::text) AS username,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc08 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'encrypted_dbs'::text) AS encrypted_dbs,
    (j.value ->> 'full_recovery_dbs'::text) AS full_recovery_dbs,
    (j.value ->> 'server_edition'::text) AS server_edition,
    (j.value ->> 'training_db_count'::text) AS training_db_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc08_8 AS
 SELECT (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'encrypted_dbs'::text) AS encrypted_dbs,
    (j.value ->> 'server_edition'::text) AS server_edition,
    (j.value ->> 'full_recovery_dbs'::text) AS full_recovery_dbs,
    (j.value ->> 'training_db_count'::text) AS training_db_count,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC08-8'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc11 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'classification'::text) AS classification,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'full_recovery_dbs'::text) AS full_recovery_dbs,
    (j.value ->> 'has_tde'::text) AS has_tde,
    (j.value ->> 'last_backup'::text) AS last_backup,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    (j.value ->> 'sample_test_db_count'::text) AS sample_test_db_count,
    (j.value ->> 'tde_encrypted_dbs'::text) AS tde_encrypted_dbs,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc11_11 AS
 SELECT (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'encrypted_dbs'::text) AS encrypted_dbs,
    (j.value ->> 'server_edition'::text) AS server_edition,
    (j.value ->> 'full_recovery_dbs'::text) AS full_recovery_dbs,
    (j.value ->> 'training_db_count'::text) AS training_db_count,
    (j.value ->> 'has_tde'::text) AS has_tde,
    to_timestamp((((((j.value ->> 'last_backup'::text))::bigint)::numeric / 1000.0))::double precision) AS last_backup,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'classification'::text) AS classification,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC11-11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'naming_quality'::text) AS naming_quality,
    (j.value ->> 'recovery_model_desc'::text) AS recovery_model_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc14 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'user_access_desc'::text) AS user_access_desc,
    (j.value ->> 'is_db_chaining_on'::text) AS is_db_chaining_on,
    (j.value ->> 'is_trustworthy_on'::text) AS is_trustworthy_on,
    (j.value ->> 'common'::text) AS common,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'authentication_type'::text) AS authentication_type,
    (j.value ->> 'user_db_count'::text) AS user_db_count,
    (j.value ->> 'datname'::text) AS datname,
    (j.value ->> 'numbackends'::text) AS numbackends,
    (j.value ->> 'stats_reset'::text) AS stats_reset,
    (j.value ->> 'datdba'::text) AS datdba,
    (j.value ->> 'table_schema'::text) AS table_schema,
    to_timestamp((((((j.value ->> 'last_update'::text))::bigint)::numeric / 3.0))::double precision) AS last_update,
    (j.value ->> 'value'::text) AS value_val,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-003-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'current_database'::text) AS current_database,
    (j.value ->> 'is_trustworthy'::text) AS is_trustworthy,
    (j.value ->> 'sql_service_account'::text) AS sql_service_account,
    (j.value ->> 'unsafe_assembly_count'::text) AS unsafe_assembly_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'clr_enabled'::text) AS clr_enabled,
    (j.value ->> 'clr_strict_security'::text) AS clr_strict_security,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_owner'::text) AS db_owner,
    (j.value ->> 'is_trustworthy_on'::text) AS is_trustworthy_on,
    (j.value ->> 'owner_is_sysadmin'::text) AS owner_is_sysadmin,
    (j.value ->> 'unsafe_assemblies'::text) AS unsafe_assemblies,
    (j.value ->> 'user_assemblies'::text) AS user_assemblies,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc12 AS
 SELECT r.server,
    (j.value ->> 'clr_exposure'::text) AS clr_exposure,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'db_owner'::text) AS db_owner,
    (j.value ->> 'is_trustworthy_on'::text) AS is_trustworthy_on,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-004-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'entity_name'::text) AS entity_name,
    (j.value ->> 'success'::text) AS success,
    (j.value ->> 'failure'::text) AS failure,
    (j.value ->> 'parameter'::text) AS parameter,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc02 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc05 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS "Global",
    (j.value ->> 'Session'::text) AS "Session",
    (j.value ->> 'Status'::text) AS "Status",
    (j.value ->> 'TraceFlag'::text) AS "TraceFlag",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'ag_count'::text) AS ag_count,
    (j.value ->> 'full_recovery_dbs'::text) AS full_recovery_dbs,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'server_edition'::text) AS server_edition,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'tde_encrypted_dbs'::text) AS tde_encrypted_dbs,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc07 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc08 AS
 SELECT r.server,
    (j.value ->> 'last_restart'::text) AS last_restart,
    (j.value ->> 'machine_name'::text) AS machine_name,
    (j.value ->> 'sql_version'::text) AS sql_version,
    (j.value ->> 'startup_trace_flag_count'::text) AS startup_trace_flag_count,
    (j.value ->> 'startup_trace_flags'::text) AS startup_trace_flags,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc10 AS
 SELECT r.server,
    (j.value ->> 'drive_count'::text) AS drive_count,
    (j.value ->> 'errorlog_file_count'::text) AS errorlog_file_count,
    (j.value ->> 'errors_per_sec'::text) AS errors_per_sec,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'last_restart'::text) AS last_restart,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc11 AS
 SELECT r.server,
    (j.value ->> 'dbsc_availability'::text) AS dbsc_availability,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'full_version'::text) AS full_version,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'tf_1117_1118_2371_status'::text) AS tf_1117_1118_2371_status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc12 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'plan_guides_count'::text) AS plan_guides_count,
    (j.value ->> 'qs_desired_state'::text) AS qs_desired_state,
    (j.value ->> 'query_store_check'::text) AS query_store_check,
    (j.value ->> 'query_store_enabled'::text) AS query_store_enabled,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc14 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS "Global",
    (j.value ->> 'Session'::text) AS "Session",
    (j.value ->> 'Status'::text) AS "Status",
    (j.value ->> 'TraceFlag'::text) AS "TraceFlag",
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-005-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc07 AS
 SELECT r.server,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_execution_time'::text) AS last_execution_time,
    (j.value ->> 'query_text'::text) AS query_text,
    (j.value ->> 'source_database'::text) AS source_database,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-006-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc09 AS
 SELECT r.server,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'session_name'::text) AS session_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-006-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc14 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-006-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc15 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'mutual_auth_status'::text) AS mutual_auth_status,
    (j.value ->> 'net_transport'::text) AS net_transport,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-006-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc16 AS
 SELECT r.server,
    (j.value ->> 'admin_role_members'::text) AS admin_role_members,
    (j.value ->> 'linked_server_count'::text) AS linked_server_count,
    (j.value ->> 'non_sysadmin_view_server_state_grants'::text) AS non_sysadmin_view_server_state_grants,
    (j.value ->> 'view_any_definition_grants'::text) AS view_any_definition_grants,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-CFG-006-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'unencrypted_connections'::text) AS unencrypted_connections,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'pct'::text) AS pct,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'cf_name'::text) AS cf_name,
    (j.value ->> 'cf_effective'::text) AS cf_effective,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'network_service_banner'::text) AS network_service_banner,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'program_name'::text) AS program_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'client_interface_name'::text) AS client_interface_name,
    (j.value ->> 'client_version'::text) AS client_version,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc04 AS
 SELECT r.server,
    (j.value ->> 'client_interface_name'::text) AS client_interface_name,
    (j.value ->> 'client_version'::text) AS client_version,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'encrypted_count'::text) AS encrypted_count,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    (j.value ->> 'unencrypted_count'::text) AS unencrypted_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'cert_health'::text) AS cert_health,
    (j.value ->> 'cert_status'::text) AS cert_status,
    (j.value ->> 'certificate_id'::text) AS certificate_id,
    (j.value ->> 'configured_cert_thumbprint'::text) AS configured_cert_thumbprint,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'expiry_date'::text) AS expiry_date,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'start_date'::text) AS start_date,
    (j.value ->> 'subject'::text) AS subject,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc08 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'cert_status'::text) AS cert_status,
    (j.value ->> 'configured_cert_thumbprint'::text) AS configured_cert_thumbprint,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'instance_name'::text) AS instance_name,
    (j.value ->> 'machine_name'::text) AS machine_name,
    (j.value ->> 'program_name'::text) AS program_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'net_transport'::text) AS net_transport,
    (j.value ->> 'program_name'::text) AS program_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'unencrypted_connections'::text) AS unencrypted_connections,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'rule_count'::text) AS rule_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc11 AS
 SELECT r.server,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text)) AS host,
    (j.value ->> 'login_name'::text) AS username,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypted_count'::text) AS encrypted_count,
    (j.value ->> 'unencrypted_count'::text) AS unencrypted_count,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'connection_type'::text) AS connection_type,
    (j.value ->> 'conn_count'::text) AS conn_count,
    (j.value ->> 'session_count'::text) AS session_count,
    (j.value ->> 'encryption_info'::text) AS encryption_info,
    (j.value ->> 'ssl'::text) AS ssl,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc12 AS
 SELECT r.server,
    (j.value ->> 'require_secure_transport'::text) AS require_secure_transport,
    (j.value ->> 'no_ssl_users'::text) AS no_ssl_users,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value_val,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'audit_action_name'::text) AS audit_action_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'unencrypted_connections'::text) AS unencrypted_connections,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'require_secure_transport'::text) AS require_secure_transport,
    (j.value ->> 'total'::text) AS total,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'plaintext'::text) AS plaintext,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_condition'::text) AS audit_condition,
    (j.value ->> 'trigger_name'::text) AS trigger_name,
    (j.value ->> 'trigger_type'::text) AS trigger_type,
    (j.value ->> 'triggering_event'::text) AS triggering_event,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'check__etc_crypto_policies_state_current_on_rhel_centos'::text) AS check__etc_crypto_policies_state_current_on_rhel_centos,
    (j.value ->> 'cnf_for_minprotocol'::text) AS cnf_for_minprotocol,
    (j.value ->> 'value'::text) AS value_val,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'modern_tls_connections'::text) AS modern_tls_connections,
    (j.value ->> 'old_tls_connections'::text) AS old_tls_connections,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'distinct_apps'::text) AS distinct_apps,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    (j.value ->> 'tls_version'::text) AS tls_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'active_audit_specs'::text) AS active_audit_specs,
    (j.value ->> 'active_audits'::text) AS active_audits,
    (j.value ->> 'old_tls_connections'::text) AS old_tls_connections,
    (j.value ->> 'tls_xe_sessions'::text) AS tls_xe_sessions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'build_type'::text) AS build_type,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'tls12_status'::text) AS tls12_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'database_id'::text) AS database_id,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'state_desc'::text) AS state_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'encrypted_count'::text) AS encrypted_count,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'encryption_state_desc'::text) AS encryption_state_desc,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'key_length'::text) AS key_length,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'encryption_alg'::text) AS encryption_alg,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc02 AS
 SELECT r.server,
    (j.value ->> 'banner'::text) AS banner,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'encrypted_count'::text) AS encrypted_count,
    (j.value ->> 'comp_name'::text) AS comp_name,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'version'::text) AS version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'unencrypted_db_count'::text) AS unencrypted_db_count,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'detected_usages'::text) AS detected_usages,
    (j.value ->> 'currently_used'::text) AS currently_used,
    to_timestamp((((((j.value ->> 'first_usage_date'::text))::bigint)::numeric / 3.0))::double precision) AS first_usage_date,
    to_timestamp((((((j.value ->> 'last_usage_date'::text))::bigint)::numeric / 3.0))::double precision) AS last_usage_date,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc04 AS
 SELECT r.server,
    (j.value ->> 'wrl_type'::text) AS wrl_type,
    (j.value ->> 'wrl_parameter'::text) AS wrl_parameter,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'wallet_type'::text) AS wallet_type,
    (j.value ->> 'keystore_mode'::text) AS keystore_mode,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'plugin_type'::text) AS plugin_type,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc10 AS
 SELECT r.server,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'contents'::text) AS contents,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'encrypted_count'::text) AS encrypted_count,
    (j.value ->> 'user_objects_mb'::text) AS user_objects_mb,
    (j.value ->> 'internal_objects_mb'::text) AS internal_objects_mb,
    (j.value ->> 'version_store_mb'::text) AS version_store_mb,
    (j.value ->> 'free_mb'::text) AS free_mb,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc13 AS
 SELECT r.server,
    (j.value ->> 'create_date'::text) AS create_date,
    (j.value ->> 'environment_guess'::text) AS environment_guess,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'default_version'::text) AS default_version,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'state_desc'::text) AS state_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'key_length'::text) AS key_length,
    (j.value ->> 'wrl_type'::text) AS wrl_type,
    (j.value ->> 'wrl_parameter'::text) AS wrl_parameter,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'wallet_type'::text) AS wallet_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc16 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'subject'::text) AS subject,
    to_timestamp((((((j.value ->> 'start_date'::text))::bigint)::numeric / 3.0))::double precision) AS start_date,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    (j.value ->> 'pvt_key_encryption_type_desc'::text) AS pvt_key_encryption_type_desc,
    (j.value ->> 'days_expired'::text) AS days_expired,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'wrl_type'::text) AS wrl_type,
    (j.value ->> 'wrl_parameter'::text) AS wrl_parameter,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'wallet_type'::text) AS wallet_type,
    (j.value ->> 'wallet_order'::text) AS wallet_order,
    (j.value ->> 'key_id'::text) AS key_id,
    to_timestamp((((((j.value ->> 'activation_time'::text))::bigint)::numeric / 3.0))::double precision) AS activation_time,
    (j.value ->> 'backed_up'::text) AS backed_up,
    (j.value ->> 'creator_dbname'::text) AS creator_dbname,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-003-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'conf'::text) AS conf,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    COALESCE((j.value ->> 'status'::text), (j.value ->> 'type'::text)) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'input_type'::text) AS input_type,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'output_bytes_display'::text) AS output_bytes_display,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc03 AS
 SELECT r.server,
    (j.value ->> 'asym_key_count'::text) AS asym_key_count,
    (j.value ->> 'backup_start_date'::text) AS backup_start_date,
    (j.value ->> 'backup_type'::text) AS backup_type,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'ekm_provider_count'::text) AS ekm_provider_count,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'master_dmk_exists'::text) AS master_dmk_exists,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'tde_enabled'::text) AS tde_enabled,
    (j.value ->> 'valid_cert_count'::text) AS valid_cert_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc05 AS
 SELECT r.server,
    (j.value ->> 'backup_start_date'::text) AS backup_start_date,
    (j.value ->> 'backup_type'::text) AS backup_type,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'tde_enabled'::text) AS tde_enabled,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc06 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'limit_gb'::text) AS limit_gb,
    (j.value ->> 'used_gb'::text) AS used_gb,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'conf'::text) AS conf,
    (j.value ->> 'value'::text) AS value_val,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc08 AS
 SELECT r.server,
    (j.value ->> 'conf'::text) AS conf,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc10 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'key_id'::text) AS key_id,
    to_timestamp((((((j.value ->> 'activation_time'::text))::bigint)::numeric / 3.0))::double precision) AS activation_time,
    (j.value ->> 'key_age_days'::text) AS key_age_days,
    (j.value ->> 'backed_up'::text) AS backed_up,
    (j.value ->> 'creator_dbname'::text) AS creator_dbname,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'extname'::text) AS extname,
    to_timestamp((((((j.value ->> 'expiry_date'::text))::bigint)::numeric / 3.0))::double precision) AS expiry_date,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'pvt_key_encryption_type_desc'::text) AS pvt_key_encryption_type_desc,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc11 AS
 SELECT r.server,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'tde_wallet'::text) AS tde_wallet,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'encrypted_tablespaces'::text) AS encrypted_tablespaces,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc13 AS
 SELECT r.server,
    (j.value ->> 'device_type'::text) AS device_type,
    to_timestamp((((((j.value ->> 'completion_time'::text))::bigint)::numeric / 3.0))::double precision) AS completion_time,
    (j.value ->> 'encrypted'::text) AS encrypted,
    COALESCE((j.value ->> 'status'::text), (j.value ->> 'type'::text)) AS state_val,
    (j.value ->> 'conf'::text) AS conf,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc15 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'datname'::text) AS datname,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    COALESCE((j.value ->> 'status'::text), (j.value ->> 'type'::text)) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'owner'::text) AS username,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'encryption_alg'::text) AS encryption_alg,
    (j.value ->> 'salt'::text) AS salt,
    (j.value ->> 'wrl_type'::text) AS wrl_type,
    (j.value ->> 'wrl_parameter'::text) AS wrl_parameter,
    (j.value ->> 'wallet_type'::text) AS wallet_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc16 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'conf'::text) AS conf,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'step_name'::text) AS step_name,
    COALESCE((j.value ->> 'command'::text), (j.value ->> 'type'::text)) AS state_val,
    to_timestamp((((((j.value ->> 'date_created'::text))::bigint)::numeric / 3.0))::double precision) AS date_created,
    to_timestamp((((((j.value ->> 'date_modified'::text))::bigint)::numeric / 3.0))::double precision) AS date_modified,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    (j.value ->> 'total_backups'::text) AS total_backups,
    (j.value ->> 'unencrypted'::text) AS unencrypted,
    (j.value ->> 'encrypted'::text) AS encrypted,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-004-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'current_encrypt'::text) AS current_encrypt,
    (j.value ->> 'current_protocol'::text) AS current_protocol,
    (j.value ->> 'force_encryption_config'::text) AS force_encryption_config,
    (j.value ->> 'is_clustered'::text) AS is_clustered,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'plugin'::text) AS plugin,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'algorithm_desc'::text) AS algorithm_desc,
    (j.value ->> 'key_length'::text) AS key_length,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'password_versions'::text) AS password_versions,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'database_name'::text) AS db,
    to_timestamp((((((j.value ->> 'backup_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_start_date,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'compressed_backup_size___1024___1024'::text) AS compressed_backup_size___1024___1024,
    (j.value ->> 'encryption_status'::text) AS encryption_status,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_encrypted'::text) AS is_encrypted,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-ENC-005-RC03'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc10 AS
 SELECT r.server,
    (j.value ->> 'encrypted_connections'::text) AS encrypted_connections,
    (j.value ->> 'tls_connections'::text) AS tls_connections,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-005-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc11 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'protocol_type'::text) AS protocol_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-005-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc13 AS
 SELECT r.server,
    (j.value ->> 'wrl_type'::text) AS wrl_type,
    (j.value ->> 'status'::text) AS state,
    (j.value ->> 'wallet_type'::text) AS wallet_type,
    (j.value ->> 'keystore_mode'::text) AS keystore_mode,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'algorithm_desc'::text) AS algorithm_desc,
    (j.value ->> 'key_length'::text) AS key_length,
    (j.value ->> 'pvt_key_encryption_type_desc'::text) AS pvt_key_encryption_type_desc,
    (j.value ->> 'strength_assessment'::text) AS strength_assessment,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-005-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc14 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'cipher_count'::text) AS cipher_count,
    (j.value ->> 'ssl_connections'::text) AS ssl_connections,
    (j.value ->> 'encrypted_connections'::text) AS encrypted_connections,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'audit_action_name'::text) AS audit_action_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'audit_option'::text) AS audit_option,
    (j.value ->> 'network_service_banner'::text) AS network_service_banner,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-ENC-005-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'line'::text) AS line,
    (j.value ->> 'text'::text) AS query_text,
    (j.value ->> 'routine_type'::text) AS routine_type,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'definition_length'::text) AS definition_length,
    (j.value ->> 'object_id'::text) AS object_id,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'function_def'::text) AS function_def,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc04 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text)) AS username,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'object_type'::text) AS object_type,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_ddl_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_ddl_time,
    (j.value ->> 'age_days'::text) AS age_days,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    to_timestamp((((((j.value ->> 'last_altered'::text))::bigint)::numeric / 3.0))::double precision) AS last_altered,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'proc_name'::text) AS proc_name,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'age_years'::text) AS age_years,
    (j.value ->> 'parameterization_status'::text) AS parameterization_status,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC04'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc07 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'line'::text) AS line,
    (j.value ->> 'text'::text) AS query_text,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'has_exec_concat'::text) AS has_exec_concat,
    (j.value ->> 'mixed_pattern_count'::text) AS mixed_pattern_count,
    (j.value ->> 'unprotected_mixed_count'::text) AS unprotected_mixed_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc08 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'dynamic_sql_lines'::text) AS dynamic_sql_lines,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'definition_length'::text) AS definition_length,
    (j.value ->> 'approx_concat_count'::text) AS approx_concat_count,
    (j.value ->> 'approx_if_count'::text) AS approx_if_count,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'query_hash'::text) AS query_hash,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'sample_query'::text) AS sample_query,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'adhoc_plans'::text) AS adhoc_plans,
    (j.value ->> 'prepared_plans'::text) AS prepared_plans,
    (j.value ->> 'proc_plans'::text) AS proc_plans,
    (j.value ->> 'total_plans'::text) AS total_plans,
    (j.value ->> 'adhoc_pct'::text) AS adhoc_pct,
    (j.value ->> 'total_cursors'::text) AS total_cursors,
    (j.value ->> 'distinct_patterns'::text) AS distinct_patterns,
    (j.value ->> 'avg_versions'::text) AS avg_versions,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc15 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'line'::text) AS line,
    (j.value ->> 'text'::text) AS query_text,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'object_id'::text) AS object_id,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    (j.value ->> 'has_quotename'::text) AS has_quotename,
    (j.value ->> 'definition_length'::text) AS definition_length,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-001-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'xproc_name'::text) AS xproc_name,
    (j.value ->> 'execution_count'::text) AS execution_count,
    to_timestamp((((((j.value ->> 'last_execution_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_execution_time,
    to_timestamp((((((j.value ->> 'days_since_last_exec'::text))::bigint)::numeric / 3.0))::double precision) AS days_since_last_exec,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'object_name'::text) AS object_name,
    (j.value ->> 'object_type'::text) AS object_type,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    to_timestamp((((((j.value ->> 'last_ddl_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_ddl_time,
    (j.value ->> 'age_days'::text) AS age_days,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'prosecdef'::text) AS prosecdef,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'compat_version'::text) AS compat_version,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'event_schema'::text) AS event_schema,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'event_definition'::text) AS event_definition,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'job_name'::text) AS job_name,
    (j.value ->> 'job_type'::text) AS job_type,
    (j.value ->> 'job_action'::text) AS job_action,
    (j.value ->> 'enabled'::text) AS enabled,
    COALESCE((j.value ->> 'state'::text), (j.value ->> 'command'::text)) AS state,
    to_timestamp((((((j.value ->> 'last_start_date'::text))::bigint)::numeric / 3.0))::double precision) AS last_start_date,
    to_timestamp((((((j.value ->> 'next_run_date'::text))::bigint)::numeric / 3.0))::double precision) AS next_run_date,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'step_name'::text) AS step_name,
    (j.value ->> 'subsystem'::text) AS subsystem,
    (j.value ->> 'xproc_used'::text) AS xproc_used,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc07 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'credential_id'::text) AS credential_id,
    (j.value ->> 'credential_identity'::text) AS credential_identity,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'xproc_name'::text) AS xproc_name,
    (j.value ->> 'privilege'::text) AS privilege,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'proacl'::text) AS proacl,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-INJ-002-RC07'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'extversion'::text) AS extversion,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'is_state_enabled'::text) AS is_state_enabled,
    (j.value ->> 'audit_action_name'::text) AS audit_action_name,
    (j.value ->> 'class_desc'::text) AS class_desc,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'enabled_option'::text) AS enabled_option,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'non_bind_sql_count'::text) AS non_bind_sql_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'sql_firewall'::text) AS sql_firewall,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'program_name'::text) AS application_name,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'audit_enabled'::text) AS audit_enabled,
    (j.value ->> 'status'::text) AS state_val,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'lanpltrusted'::text) AS lanpltrusted,
    (j.value ->> 'rolname'::text) AS rolname,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc11 AS
 SELECT r.server,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'service_account'::text) AS service_account,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'status_desc'::text) AS status_desc,
    (j.value ->> 'privilege_assessment'::text) AS privilege_assessment,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'owner'::text)) AS username,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    (j.value ->> 'module'::text) AS module,
    (j.value ->> 'one_exec_sql'::text) AS one_exec_sql,
    (j.value ->> 'wasted_mb'::text) AS wasted_mb,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'file_priv'::text) AS file_priv,
    (j.value ->> 'create_routine_priv'::text) AS create_routine_priv,
    (j.value ->> 'execute_priv'::text) AS execute_priv,
    (j.value ->> 'nspname'::text) AS nspname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    (j.value ->> 'privilege_type'::text) AS privilege_type,
    (j.value ->> 'is_grantable'::text) AS is_grantable,
    (j.value ->> 'active_sessions'::text) AS active_sessions,
    to_timestamp((((((j.value ->> 'last_activity'::text))::bigint)::numeric / 3.0))::double precision) AS last_activity,
    COALESCE((j.value ->> 'text'::text), (j.value ->> 'query_preview'::text)) AS query_text,
    (j.value ->> 'execution_count'::text) AS execution_count,
    to_timestamp((((((j.value ->> 'last_execution_time'::text))::bigint)::numeric / 3.0))::double precision) AS last_execution_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc14 AS
 SELECT r.server,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'permission_set_desc'::text) AS permission_set_desc,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'is_user_defined'::text) AS is_user_defined,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'definition'::text) AS definition,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc15 AS
 SELECT r.server,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'proc_name'::text) AS proc_name,
    (j.value ->> 'injection_risk_level'::text) AS injection_risk_level,
    (j.value ->> 'is_enabled'::text) AS is_enabled,
    (j.value ->> 'state_desc'::text) AS state_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc16 AS
 SELECT r.server,
    (j.value ->> 'routine_schema'::text) AS routine_schema,
    (j.value ->> 'routine_name'::text) AS routine_name,
    (j.value ->> 'routine_type'::text) AS routine_type,
    (j.value ->> 'no_sql_firewall'::text) AS no_sql_firewall,
    (j.value ->> 'tgname'::text) AS tgname,
    (j.value ->> 'relname'::text) AS relname,
    (j.value ->> 'proname'::text) AS proname,
    (j.value ->> 'lanname'::text) AS lanname,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'event_schema'::text) AS event_schema,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'event'::text) AS event,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-INJ-002-RC16'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    COALESCE((j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'listener_id'::text) AS listener_id,
    (j.value ->> 'ip_address'::text) AS ip_address,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'connections'::text) AS connections,
    (j.value ->> 'local_net_address'::text) AS local_net_address,
    (j.value ->> 'local_tcp_port'::text) AS local_tcp_port,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'login_name'::text), (j.value ->> 'user'::text)) AS username,
    COALESCE((j.value ->> 'host_name'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'source_host'::text) AS source_host,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    (j.value ->> 'session_count'::text) AS session_count,
    to_timestamp((((((j.value ->> 'event_time'::text))::bigint)::numeric / 3.0))::double precision) AS event_time,
    (j.value ->> 'error_number'::text) AS error_number,
    (j.value ->> 'error_message'::text) AS error_message,
    (j.value ->> 'authentication_string'::text) AS authentication_string,
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state_val,
    (j.value ->> 'database'::text) AS database_val,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'netmask'::text) AS netmask,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    to_timestamp((((((j.value ->> 'login_time'::text))::bigint)::numeric / 3.0))::double precision) AS login_time,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'ip_address'::text) AS ip_address,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'userhost'::text) AS userhost,
    (j.value ->> 'failed_attempts'::text) AS failed_attempts,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'listener_id'::text) AS listener_id,
    (j.value ->> 'ip_address'::text) AS ip_address,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'local_net_address'::text) AS local_net_address,
    to_timestamp((((((j.value ->> 'connect_time'::text))::bigint)::numeric / 3.0))::double precision) AS connect_time,
    (j.value ->> 'login_name'::text) AS username,
    (j.value ->> 'host_name'::text) AS host,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    (j.value ->> 'host_pattern'::text) AS host_pattern,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'extname'::text) AS extname,
    (j.value ->> 'machine'::text) AS machine,
    (j.value ->> 'osuser'::text) AS osuser,
    (j.value ->> 'setting'::text) AS setting,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-NET-001-RC03'::text) AND ((j.value ->> 'host_name'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'ip_prefix'::text) AS ip_prefix,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'ag_count'::text) AS ag_count,
    (j.value ->> 'credential_count'::text) AS credential_count,
    (j.value ->> 'job_count'::text) AS job_count,
    (j.value ->> 'log_shipping_count'::text) AS log_shipping_count,
    (j.value ->> 'mail_profile_count'::text) AS mail_profile_count,
    (j.value ->> 'recent_backup_count'::text) AS recent_backup_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'create_date'::text))::bigint)::numeric / 3.0))::double precision) AS create_date,
    (j.value ->> 'days_until_expiration'::text) AS days_until_expiration,
    to_timestamp((((((j.value ->> 'password_last_set'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_set,
    (j.value ->> 'is_expired'::text) AS is_expired,
    (j.value ->> 'is_locked'::text) AS is_locked,
    (j.value ->> 'must_change'::text) AS must_change,
    (j.value ->> 'type_desc'::text) AS type_desc,
    to_timestamp((((((j.value ->> 'modify_date'::text))::bigint)::numeric / 3.0))::double precision) AS modify_date,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    to_timestamp((((((j.value ->> 'days_since_created'::text))::bigint)::numeric / 3.0))::double precision) AS days_since_created,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'account_status'::text) AS account_status,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'days_active'::text) AS days_active,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'line_number'::text) AS line_number,
    (j.value ->> 'type'::text) AS state,
    (j.value ->> 'database'::text) AS database,
    (j.value ->> 'user_name'::text) AS user_name,
    (j.value ->> 'address'::text) AS address,
    (j.value ->> 'auth_method'::text) AS auth_method,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'grant_priv'::text) AS grant_priv,
    (j.value ->> 'create_user_priv'::text) AS create_user_priv,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-NET-001-RC12'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'default_count'::text) AS default_count,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'isdefault'::text) AS isdefault,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-NET-002-RC02'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc06 AS
 SELECT r.server,
    COALESCE((j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    (j.value ->> 'machine'::text) AS host,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'source'::text) AS source,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'ip_address'::text) AS ip_address,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'local_tcp_port'::text) AS local_tcp_port,
    (j.value ->> 'distinct_hosts'::text) AS distinct_hosts,
    (j.value ->> 'distinct_programs'::text) AS distinct_programs,
    (j.value ->> 'distinct_machines'::text) AS distinct_machines,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-NET-002-RC06'::text) AND ((j.value ->> 'machine'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc08 AS
 SELECT r.server,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value_val,
    (j.value ->> 'servicename'::text) AS servicename,
    (j.value ->> 'status_desc'::text) AS status_desc,
    (j.value ->> 'startup_type_desc'::text) AS startup_type_desc,
    (j.value ->> 'local_tcp_port'::text) AS local_tcp_port,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'source'::text) AS source,
    (j.value ->> 'port'::text) AS port,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC08'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'auth_scheme'::text) AS auth_scheme,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'listening_port'::text) AS listening_port,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'remote_dac_enabled'::text) AS remote_dac_enabled,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'total_tcp_connections'::text) AS total_tcp_connections,
    (j.value ->> 'unencrypted_connections'::text) AS unencrypted_connections,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'listening_port'::text) AS listening_port,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'service_pack'::text) AS service_pack,
    (j.value ->> 'version_banner'::text) AS version_banner,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc13 AS
 SELECT r.server,
    (j.value ->> 'failed_login_count'::text) AS failed_login_count,
    (j.value ->> 'earliest_failure'::text) AS earliest_failure,
    (j.value ->> 'latest_failure'::text) AS latest_failure,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'max_connect_errors'::text) AS max_connect_errors,
    (j.value ->> 'policy_name'::text) AS policy_name,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'plugin_name'::text) AS plugin_name,
    (j.value ->> 'plugin_status'::text) AS plugin_status,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'resource_name'::text) AS resource_name,
    (j.value ->> 'limit'::text) AS limit_val,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc14 AS
 SELECT r.server,
    (j.value ->> 'instance_name'::text) AS instance_name,
    to_timestamp((((((j.value ->> 'startup_time'::text))::bigint)::numeric / 3.0))::double precision) AS startup_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    (j.value ->> 'version'::text) AS version,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'source'::text) AS source,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc15 AS
 SELECT r.server,
    (j.value ->> 'browser_status'::text) AS browser_status,
    (j.value ->> 'listening_port'::text) AS listening_port,
    (j.value ->> 'sa_enabled'::text) AS sa_enabled,
    (j.value ->> 'windows_auth_only'::text) AS windows_auth_only,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-002-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_003_rc06 AS
 SELECT r.server,
    (j.value ->> 'active_external_scripts'::text) AS active_external_scripts,
    (j.value ->> 'configured_value'::text) AS configured_value,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'total_executions'::text) AS total_executions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-003-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_003_rc15 AS
 SELECT r.server,
    (j.value ->> 'command'::text) AS command,
    (j.value ->> 'date_created'::text) AS date_created,
    (j.value ->> 'date_modified'::text) AS date_modified,
    (j.value ->> 'job_enabled'::text) AS job_enabled,
    (j.value ->> 'job_name'::text) AS job_name,
    (j.value ->> 'step_name'::text) AS step_name,
    (j.value ->> 'subsystem'::text) AS subsystem,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-NET-003-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'full_version_string'::text) AS full_version_string,
    (j.value ->> 'lifecycle_status'::text) AS lifecycle_status,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'minor_version'::text) AS minor_version,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'update_level'::text) AS update_level,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc02 AS
 SELECT r.server,
    (j.value ->> 'dbid'::text) AS dbid,
    (j.value ->> 'name'::text) AS username,
    to_timestamp((((((j.value ->> 'created'::text))::bigint)::numeric / 3.0))::double precision) AS created,
    (j.value ->> 'log_mode'::text) AS log_mode,
    (j.value ->> 'open_mode'::text) AS open_mode,
    (j.value ->> 'banner_full'::text) AS banner_full,
    (j.value ->> 'con_id'::text) AS con_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'deprecated_feature'::text) AS deprecated_feature,
    (j.value ->> 'usage_count'::text) AS usage_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'connection_count'::text) AS connection_count,
    (j.value ->> 'distinct_clients'::text) AS distinct_clients,
    (j.value ->> 'protocol_version'::text) AS protocol_version,
    (j.value ->> 'tds_version_desc'::text) AS tds_version_desc,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'compat_gap'::text) AS compat_gap,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'engine_compat_level'::text) AS engine_compat_level,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc12 AS
 SELECT r.server,
    to_timestamp((((((j.value ->> 'last_patch_date'::text))::bigint)::numeric / 3.0))::double precision) AS last_patch_date,
    (j.value ->> 'days_since_patch'::text) AS days_since_patch,
    (j.value ->> 'banner_full'::text) AS banner_full,
    to_timestamp((((((j.value ->> 'sqlserver_start_time'::text))::bigint)::numeric / 3.0))::double precision) AS sqlserver_start_time,
    (j.value ->> 'days_since_restart'::text) AS days_since_restart,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'product_build_type'::text) AS product_build_type,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_update_level'::text) AS product_update_level,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    (j.value ->> 'uptime_days'::text) AS uptime_days,
    (j.value ->> 'uptime_hours'::text) AS uptime_hours,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'compat_version'::text) AS compat_version,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'current_major_version'::text) AS current_major_version,
    (j.value ->> 'database_name'::text) AS database_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc10 AS
 SELECT r.server,
    (j.value ->> 'active_requests'::text) AS active_requests,
    (j.value ->> 'active_user_sessions'::text) AS active_user_sessions,
    (j.value ->> 'long_running_transactions'::text) AS long_running_transactions,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-002-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc12 AS
 SELECT r.server,
    (j.value ->> 'branch_description'::text) AS branch_description,
    (j.value ->> 'days_since_restart'::text) AS days_since_restart,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'patch_staleness'::text) AS patch_staleness,
    (j.value ->> 'product_build_type'::text) AS product_build_type,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_update_level'::text) AS product_update_level,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'sqlserver_start_time'::text) AS sqlserver_start_time,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PAT-002-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'cek_value_count'::text) AS cek_value_count,
    (j.value ->> 'column_encryption_key_count'::text) AS column_encryption_key_count,
    (j.value ->> 'column_master_key_count'::text) AS column_master_key_count,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'encryption_state_desc'::text) AS encryption_state_desc,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'key_length'::text) AS key_length,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc03 AS
 SELECT r.server,
    (j.value ->> 'relname'::text) AS relname,
    (j.value ->> 'idx_scan'::text) AS idx_scan,
    (j.value ->> 'n_tup_upd'::text) AS n_tup_upd,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'contents'::text) AS contents,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc05 AS
 SELECT r.server,
    (j.value ->> 'algorithm_desc'::text) AS algorithm_desc,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'database_created'::text) AS database_created,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'encryption_capability'::text) AS encryption_capability,
    (j.value ->> 'key_length'::text) AS key_length,
    (j.value ->> 'key_name'::text) AS key_name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc05_5 AS
 SELECT (j.value ->> 'database_name'::text) AS database_name,
    to_timestamp((((((j.value ->> 'database_created'::text))::bigint)::numeric / 1000.0))::double precision) AS database_created,
    (j.value ->> 'compatibility_level'::text) AS compatibility_level,
    (j.value ->> 'encryption_capability'::text) AS encryption_capability,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC05-5'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc07 AS
 SELECT r.server,
    (j.value ->> 'createdate'::text) AS createdate,
    (j.value ->> 'description'::text) AS description,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'folder_name'::text) AS folder_name,
    (j.value ->> 'has_bulk_insert'::text) AS has_bulk_insert,
    (j.value ->> 'has_insert'::text) AS has_insert,
    (j.value ->> 'last_execution_time'::text) AS last_execution_time,
    (j.value ->> 'package_name'::text) AS package_name,
    (j.value ->> 'packageformat'::text) AS packageformat,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc09 AS
 SELECT r.server,
    (j.value ->> 'cert_name'::text) AS cert_name,
    (j.value ->> 'days_until_expiry'::text) AS days_until_expiry,
    (j.value ->> 'expiry_date'::text) AS expiry_date,
    (j.value ->> 'pvt_key_encryption_type_desc'::text) AS pvt_key_encryption_type_desc,
    (j.value ->> 'start_date'::text) AS start_date,
    (j.value ->> 'subject'::text) AS subject,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc10 AS
 SELECT r.server,
    (j.value ->> 'edition'::text) AS edition,
    (j.value ->> 'encryption_key_count'::text) AS encryption_key_count,
    (j.value ->> 'feature_utilization'::text) AS feature_utilization,
    (j.value ->> 'major_version'::text) AS major_version,
    (j.value ->> 'masked_column_count'::text) AS masked_column_count,
    (j.value ->> 'masking_support_level'::text) AS masking_support_level,
    (j.value ->> 'master_key_count'::text) AS master_key_count,
    (j.value ->> 'product_level'::text) AS product_level,
    (j.value ->> 'product_version'::text) AS product_version,
    (j.value ->> 'update_level'::text) AS update_level,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC10'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc11 AS
 SELECT r.server,
    (j.value ->> 'backup_finish_date'::text) AS backup_finish_date,
    (j.value ->> 'backup_type'::text) AS backup_type,
    (j.value ->> 'backup_type_desc'::text) AS backup_type_desc,
    (j.value ->> 'cert_expiry'::text) AS cert_expiry,
    (j.value ->> 'certificate_name'::text) AS certificate_name,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'encryption_state_desc'::text) AS encryption_state_desc,
    (j.value ->> 'encryptor_thumbprint'::text) AS encryptor_thumbprint,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'is_copy_only'::text) AS is_copy_only,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'physical_device_name'::text) AS physical_device_name,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'tde_algorithm'::text) AS tde_algorithm,
    (j.value ->> 'tde_key_length'::text) AS tde_key_length,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC11'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12 AS
 SELECT r.server,
    COALESCE((j.value ->> 'owner'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'max_length'::text) AS max_length,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'data_length'::text) AS data_length,
    (j.value ->> 'pii_category'::text) AS pii_category,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'character_maximum_length'::text) AS character_maximum_length,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC12'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc13 AS
 SELECT r.server,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'pii_category'::text) AS pii_category,
    (j.value ->> 'total_reads'::text) AS total_reads,
    (j.value ->> 'table_rows'::text) AS table_rows,
    (j.value ->> 'num_rows'::text) AS num_rows,
    (j.value ->> 'last_user_seek'::text) AS last_user_seek,
    (j.value ->> 'last_user_scan'::text) AS last_user_scan,
    (j.value ->> 'last_activity'::text) AS last_activity,
    (j.value ->> 'last_analyzed'::text) AS last_analyzed,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC13'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc14 AS
 SELECT r.server,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'pii_category'::text) AS pii_category,
    COALESCE((j.value ->> 'status'::text), (j.value ->> 'state'::text)) AS status,
    COALESCE((j.value ->> 'start_time'::text), (j.value ->> 'query_start'::text)) AS started_at,
    (j.value ->> 'duration_secs'::text) AS duration_secs,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC14'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc15 AS
 SELECT r.server,
    (j.value ->> 'source'::text) AS source,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'transaction_id'::text) AS transaction_id,
    (j.value ->> 'login_name'::text) AS login_name,
    COALESCE((j.value ->> 'schema_name'::text), (j.value ->> 'table_schema'::text)) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'pii_category'::text) AS pii_category,
    (j.value ->> 'execution_count'::text) AS execution_count,
    (j.value ->> 'last_execution_time'::text) AS last_execution_time,
    (j.value ->> 'avg_reads'::text) AS avg_reads,
    (j.value ->> 'avg_cpu_ms'::text) AS avg_cpu_ms,
    (j.value ->> 'transaction_begin_time'::text) AS transaction_begin_time,
    (j.value ->> 'query_text'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC15'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc01 AS
 SELECT r.server,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'package'::text) AS package,
    (j.value ->> 'session_name'::text) AS session_name,
    (j.value ->> 'startup_state'::text) AS startup_state,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc02 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'is_parameterization_forced'::text) AS is_parameterization_forced,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'parameterization_mode'::text) AS parameterization_mode,
    (j.value ->> 'pct_of_plans'::text) AS pct_of_plans,
    (j.value ->> 'plan_count'::text) AS plan_count,
    (j.value ->> 'plan_type'::text) AS plan_type,
    (j.value ->> 'size_mb'::text) AS size_mb,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc03 AS
 SELECT r.server,
    (j.value ->> 'Global'::text) AS global,
    (j.value ->> 'Session'::text) AS session,
    (j.value ->> 'Status'::text) AS status,
    (j.value ->> 'TraceFlag'::text) AS traceflag,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc05 AS
 SELECT r.server,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'package'::text) AS package,
    (j.value ->> 'session_name'::text) AS session_name,
    (j.value ->> 'startup_state'::text) AS startup_state,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC05'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc06 AS
 SELECT r.server,
    (j.value ->> 'assessment'::text) AS assessment,
    (j.value ->> 'current_value'::text) AS current_value,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC06'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc07 AS
 SELECT r.server,
    (j.value ->> 'event_name'::text) AS event_name,
    (j.value ->> 'package'::text) AS package,
    (j.value ->> 'session_name'::text) AS session_name,
    (j.value ->> 'startup_state'::text) AS startup_state,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC07'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc09 AS
 SELECT r.server,
    (j.value ->> 'buffer_count'::text) AS buffer_count,
    (j.value ->> 'buffer_size'::text) AS buffer_size,
    (j.value ->> 'event_count'::text) AS event_count,
    (j.value ->> 'is_default'::text) AS is_default,
    (j.value ->> 'max_file_size_mb'::text) AS max_file_size_mb,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'status'::text) AS status,
    (j.value ->> 'status_desc'::text) AS status_desc,
    (j.value ->> 'stop_time'::text) AS stop_time,
    (j.value ->> 'trace_file_path'::text) AS trace_file_path,
    (j.value ->> 'trace_id'::text) AS trace_id,
    (j.value ->> 'trace_type'::text) AS trace_type,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-002-RC09'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'rows'::text) AS rows,
    (j.value ->> 'check_name'::text) AS check_name,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    (j.value ->> 'name'::text) AS setting_name,
    (j.value ->> 'value'::text) AS setting_value,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-003-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc01 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS db,
    (j.value ->> 'missing_ppl_security_level_parameter'::text) AS missing_ppl_security_level_parameter,
    (j.value ->> 'missing_ppl_security_level_option'::text) AS missing_ppl_security_level_option,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-003-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc03 AS
 SELECT r.server,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'setting'::text) AS setting,
    (j.value ->> 'value_in_use'::text) AS value_in_use,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-003-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    (j.value ->> 'ssl'::text) AS ssl,
    (j.value ->> 'ssl_type'::text) AS ssl_type,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-004-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc01 AS
 SELECT r.server,
    (j.value ->> 'database_name'::text) AS db,
    (j.value ->> 'encryption_state'::text) AS encryption_state,
    (j.value ->> 'key_algorithm'::text) AS key_algorithm,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'tablespace_name'::text) AS tablespace_name,
    (j.value ->> 'encrypted'::text) AS encrypted,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-004-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'session_id'::text)) AS session_id,
    (j.value ->> 'encrypt_option'::text) AS encrypt_option,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'value'::text) AS value,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'ssl_type'::text) AS ssl_type,
    (j.value ->> 'ssl'::text) AS ssl,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-PRI-004-RC03'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_005 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'pii_table'::text) AS pii_table,
    (j.value ->> 'owner'::text) AS owner,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'name'::text) AS audit_name,
    (j.value ->> 'setting'::text) AS setting_value,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-005-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_005_rc01 AS
 SELECT r.server,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'name'::text) AS username,
    (j.value ->> 'value'::text) AS value,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-005-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'permission_name'::text) AS permission_name,
    (j.value ->> 'principal'::text) AS principal,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'role_name'::text) AS role_name,
    (j.value ->> 'last_login'::text) AS last_login,
    (j.value ->> 'last_seen'::text) AS last_seen,
    (j.value ->> 'user'::text) AS user_name,
    (j.value ->> 'host'::text) AS host,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-006-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006_rc02 AS
 SELECT r.server,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'rolname'::text) AS rolname,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-PRI-006-RC02'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    to_timestamp((((((j.value ->> 'password_last_changed'::text))::bigint)::numeric / 3.0))::double precision) AS password_last_changed,
    to_timestamp((((((j.value ->> 'last_login'::text))::bigint)::numeric / 3.0))::double precision) AS last_login,
    (j.value ->> 'rolname'::text) AS rolname,
    to_timestamp((((((j.value ->> 'last_seen'::text))::bigint)::numeric / 3.0))::double precision) AS last_seen,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-PRI-006-RC03'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_007 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'name'::text) AS principal,
    (j.value ->> 'username'::text) AS username,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'user'::text) AS user_name,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'type_desc'::text) AS type_desc,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'account_status'::text) AS account_status,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-007-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_007_rc01 AS
 SELECT r.server,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'profile'::text) AS profile,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-007-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_008 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'last_backup'::text) AS last_backup,
    (j.value ->> 'backup_finish_date'::text) AS backup_finish_date,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'has_backup_checksums'::text) AS has_backup_checksums,
    (j.value ->> 'backup_path'::text) AS backup_path,
    (j.value ->> 'data_path'::text) AS data_path,
    (j.value ->> 'last_archived_time'::text) AS last_archived_time,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-008-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_008_rc02 AS
 SELECT r.server,
    (j.value ->> 'variable_name'::text) AS variable_name,
    (j.value ->> 'variable_value'::text) AS variable_value,
    (j.value ->> 'bs_key'::text) AS bs_key,
    to_timestamp((((((j.value ->> 'completion_time'::text))::bigint)::numeric / 3.0))::double precision) AS completion_time,
    (j.value ->> 'encrypted'::text) AS encrypted,
    (j.value ->> 'database_name'::text) AS db,
    (j.value ->> 'database_name'::text) AS database_name,
    to_timestamp((((((j.value ->> 'backup_finish_date'::text))::bigint)::numeric / 3.0))::double precision) AS backup_finish_date,
    (j.value ->> 'encryptor_type'::text) AS encryptor_type,
    (j.value ->> 'has_backup_checksums'::text) AS has_backup_checksums,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-008-RC02'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_009 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'date_column'::text) AS date_column,
    (j.value ->> 'last_active_col'::text) AS last_active_col,
    (j.value ->> 'soft_delete_col'::text) AS soft_delete_col,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'row_count'::text) AS row_count,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-009-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'session_id'::text) AS session_id,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'client_net_address'::text) AS client_net_address,
    (j.value ->> 'client_addr'::text) AS client_addr,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'principal'::text) AS principal,
    (j.value ->> 'role_name'::text) AS role_name,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'failed_count'::text) AS failed_count,
    (j.value ->> 'last_failure'::text) AS last_failure,
    (j.value ->> 'start_time'::text) AS start_time,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-010-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc01 AS
 SELECT r.server,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host'::text)) AS host,
    (j.value ->> 'conn_count'::text) AS conn_count,
    COALESCE((j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    (j.value ->> 'failed_count'::text) AS failed_count,
    (j.value ->> 'os_username'::text) AS os_username,
    to_timestamp((((((j.value ->> 'last_failure'::text))::bigint)::numeric / 3.0))::double precision) AS last_failure,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-010-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc02 AS
 SELECT r.server,
    (j.value ->> 'rolname'::text) AS rolname,
    (j.value ->> 'rolsuper'::text) AS rolsuper,
    (j.value ->> 'rolcreaterole'::text) AS rolcreaterole,
    (j.value ->> 'rolcreatedb'::text) AS rolcreatedb,
    COALESCE((j.value ->> 'user'::text), (j.value ->> 'grantee'::text), (j.value ->> 'name'::text)) AS username,
    (j.value ->> 'host'::text) AS host,
    (j.value ->> 'super_priv'::text) AS super_priv,
    (j.value ->> 'grant_priv'::text) AS grant_priv,
    to_timestamp((((((j.value ->> 'granted_role'::text))::bigint)::numeric / 3.0))::double precision) AS granted_role,
    (j.value ->> 'default_role'::text) AS default_role,
    (j.value ->> 'admin_option'::text) AS admin_option,
    (j.value ->> 'role_principal_id'::text) AS role_principal_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE (((r.metric_name)::text = 'SEC-SQL-PRI-010-RC02'::text) AND ((j.value ->> 'host'::text) IS DISTINCT FROM 'dbdome'::text));

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc03 AS
 SELECT r.server,
    COALESCE((j.value ->> 'pid'::text), (j.value ->> 'session_id'::text), (j.value ->> 'sid'::text), (j.value ->> 'id'::text)) AS session_id,
    COALESCE((j.value ->> 'usename'::text), (j.value ->> 'login_name'::text), (j.value ->> 'username'::text), (j.value ->> 'user'::text)) AS username,
    COALESCE((j.value ->> 'client_addr'::text), (j.value ->> 'host_name'::text), (j.value ->> 'machine'::text), (j.value ->> 'host'::text)) AS host,
    COALESCE((j.value ->> 'application_name'::text), (j.value ->> 'program_name'::text), (j.value ->> 'program'::text)) AS application_name,
    to_timestamp((((((j.value ->> 'query_start'::text))::bigint)::numeric / 3.0))::double precision) AS query_start,
    to_timestamp((((((j.value ->> 'start_time'::text))::bigint)::numeric / 3.0))::double precision) AS start_time,
    (j.value ->> 'db'::text) AS db,
    (j.value ->> 'command'::text) AS state,
    to_timestamp((((((j.value ->> 'time'::text))::bigint)::numeric / 3.0))::double precision) AS "time",
    (j.value ->> 'info'::text) AS query_text,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-010-RC03'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_011 AS
 SELECT r.server,
    r.metric_name AS root_cause_id,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'attname'::text) AS attname,
    (j.value ->> 'owner'::text) AS owner,
    (j.value ->> 'table_schema'::text) AS table_schema,
    (j.value ->> 'finding'::text) AS finding,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text ~~ 'SEC-SQL-PRI-011-%'::text);

CREATE OR REPLACE VIEW monitoring.v_sec_sql_qe_001_rc01 AS
 SELECT r.server,
    (j.value ->> 'procedure_name'::text) AS procedure_name,
    (j.value ->> 'database_name'::text) AS database_name,
    (j.value ->> 'login_name'::text) AS login_name,
    (j.value ->> 'avg_duration_ms'::text) AS avg_duration_ms,
    (j.value ->> 'actual_duration_ms'::text) AS actual_duration_ms,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-QE-001-RC01'::text);

CREATE OR REPLACE VIEW monitoring.v_sensitive AS
 SELECT a.server,
    a.query,
    a.entry_date,
    susp.columns,
    susp.tables
   FROM (( SELECT sql_feature_predictions.query_id,
            sql_feature_predictions.entry_date,
            sql_feature_predictions.server,
            (sql_feature_predictions.features ->> 'query'::text) AS query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
     LEFT JOIN monitoring.sql_suspicious susp ON ((susp.query_id = a.query_id)))
  WHERE (a.sensitive_columns IS TRUE);

CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring.v_sensitive_columns AS
 SELECT DISTINCT table_name,
    column_name
   FROM monitoring.v_schema
  WHERE (column_name ~~* ANY (ARRAY['%fname%'::text, '%lname%'::text, '%email%'::text, '%lastname%'::text, '%firstname%'::text, '%last_name%'::text, '%phone%'::text, '%ssn%'::text, '%dob%'::text, '%birth%'::text, '%credit%'::text, '%idcard%'::text, '%idnum%'::text, '%id_card%'::text, '%id_num%'::text]))
  WITH NO DATA;

CREATE OR REPLACE VIEW monitoring.v_sql_feature_predictions AS
 SELECT server,
    query,
    dangerous_function,
    length,
    sleep_time,
    upper_ratio,
    boolean_sqli,
    long_literal,
    num_comments,
    num_keywords,
    num_literals,
    outfile_copy,
    union_select,
    schema_access,
    stacked_query,
    commented_payload,
    sensitive_columns
   FROM ( SELECT sql_feature_predictions.server,
            (sql_feature_predictions.features ->> 'query'::text) AS query,
            ((sql_feature_predictions.features ->> 'dangerous_function'::text))::boolean AS dangerous_function,
            ((sql_feature_predictions.features ->> 'length'::text))::integer AS length,
            ((sql_feature_predictions.features ->> 'sleep_time'::text))::boolean AS sleep_time,
            ((sql_feature_predictions.features ->> 'upper_ratio'::text))::numeric(12,10) AS upper_ratio,
            ((sql_feature_predictions.features ->> 'boolean_sqli'::text))::boolean AS boolean_sqli,
            ((sql_feature_predictions.features ->> 'long_literal'::text))::boolean AS long_literal,
            ((sql_feature_predictions.features ->> 'num_comments'::text))::integer AS num_comments,
            ((sql_feature_predictions.features ->> 'num_keywords'::text))::integer AS num_keywords,
            ((sql_feature_predictions.features ->> 'num_literals'::text))::integer AS num_literals,
            ((sql_feature_predictions.features ->> 'outfile_copy'::text))::boolean AS outfile_copy,
            ((sql_feature_predictions.features ->> 'union_select'::text))::boolean AS union_select,
            ((sql_feature_predictions.features ->> 'schema_access'::text))::boolean AS schema_access,
            ((sql_feature_predictions.features ->> 'stacked_query'::text))::boolean AS stacked_query,
            ((sql_feature_predictions.features ->> 'commented_payload'::text))::boolean AS commented_payload,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a;

CREATE OR REPLACE VIEW monitoring.v_sql_logins_without_password_policy_enforcement AS
 SELECT r.server,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'name'::text) AS name,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SQL Logins without password policy enforcement'::text);

CREATE OR REPLACE VIEW monitoring.v_suspiscous AS
 SELECT server,
    query,
    dangerous_function,
    length,
    sleep_time,
    upper_ratio,
    boolean_sqli,
    long_literal,
    num_comments,
    num_keywords,
    num_literals,
    outfile_copy,
    union_select,
    schema_access,
    stacked_query,
    commented_payload,
    sensitive_columns
   FROM ( SELECT sql_feature_predictions.server,
            (sql_feature_predictions.features ->> 'query'::text) AS query,
            ((sql_feature_predictions.features ->> 'dangerous_function'::text))::boolean AS dangerous_function,
            ((sql_feature_predictions.features ->> 'length'::text))::integer AS length,
            ((sql_feature_predictions.features ->> 'sleep_time'::text))::boolean AS sleep_time,
            ((sql_feature_predictions.features ->> 'upper_ratio'::text))::numeric(12,10) AS upper_ratio,
            ((sql_feature_predictions.features ->> 'boolean_sqli'::text))::boolean AS boolean_sqli,
            ((sql_feature_predictions.features ->> 'long_literal'::text))::boolean AS long_literal,
            ((sql_feature_predictions.features ->> 'num_comments'::text))::integer AS num_comments,
            ((sql_feature_predictions.features ->> 'num_keywords'::text))::integer AS num_keywords,
            ((sql_feature_predictions.features ->> 'num_literals'::text))::integer AS num_literals,
            ((sql_feature_predictions.features ->> 'outfile_copy'::text))::boolean AS outfile_copy,
            ((sql_feature_predictions.features ->> 'union_select'::text))::boolean AS union_select,
            ((sql_feature_predictions.features ->> 'schema_access'::text))::boolean AS schema_access,
            ((sql_feature_predictions.features ->> 'stacked_query'::text))::boolean AS stacked_query,
            ((sql_feature_predictions.features ->> 'commented_payload'::text))::boolean AS commented_payload,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  WHERE ((sensitive_columns IS TRUE) OR (dangerous_function IS TRUE) OR (commented_payload IS TRUE));

CREATE OR REPLACE VIEW monitoring.v_sysadmin AS
 SELECT server,
    entry_date,
    rolename,
    loginname,
    logintype
   FROM ( SELECT row_number() OVER (PARTITION BY unnamed_subquery_1.loginname ORDER BY unnamed_subquery_1.entry_date DESC) AS seq,
            unnamed_subquery_1.server,
            unnamed_subquery_1.entry_date,
            unnamed_subquery_1.rolename,
            unnamed_subquery_1.loginname,
            unnamed_subquery_1.logintype
           FROM ( SELECT r.server,
                    (j.value ->> 'RoleName'::text) AS rolename,
                    (j.value ->> 'LoginName'::text) AS loginname,
                    (j.value ->> 'LoginType'::text) AS logintype,
                    r.entry_date
                   FROM (monitoring.general_metric_metadata_results_old r
                     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
                  WHERE ((r.metric_name)::text = 'Sysadmin'::text)) unnamed_subquery_1) unnamed_subquery
  WHERE (seq = 1);

CREATE OR REPLACE VIEW monitoring.v_sysadmin_accounts_with_weakpassword_enforcement AS
 SELECT r.server,
    (j.value ->> 'LoginName'::text) AS loginname,
    (j.value ->> 'LoginType'::text) AS logintype,
    (j.value ->> 'RoleName'::text) AS rolename,
    (j.value ->> 'is_disabled'::text) AS is_disabled,
    (j.value ->> 'is_policy_checked'::text) AS is_policy_checked,
    (j.value ->> 'is_expiration_checked'::text) AS is_expiration_checked,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results_old r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE (((r.metric_name)::text = 'sysadmin accounts with weak/no password enforcement'::text) AND (r.entry_date = ( SELECT max(general_metric_metadata_results_old.entry_date) AS max
           FROM monitoring.general_metric_metadata_results_old
          WHERE ((general_metric_metadata_results_old.metric_name)::text = 'sysadmin accounts with weak/no password enforcement'::text))));

CREATE OR REPLACE VIEW monitoring.v_sysadmin_logins AS
 SELECT server,
    login_name,
    max(entry_date) AS entry_date
   FROM ( SELECT gmmr.row_id,
            gmmr.server,
            (elem.value ->> 'login_name'::text) AS login_name,
            gmmr.entry_date
           FROM (monitoring.general_metric_metadata_results_old gmmr
             LEFT JOIN LATERAL jsonb_array_elements(gmmr.metric_metadata) elem(value) ON (true))
          WHERE ((gmmr.metric_name)::text = 'Logins with sysadmin (superuser) privileges'::text)) a
  GROUP BY server, login_name;

CREATE OR REPLACE VIEW monitoring.v_top_risk_users AS
 SELECT server_name,
    db_user,
    risk_score,
    consecutive_high_risk,
    observation_count,
    avg_queries_per_hour,
    typical_hour_start,
    typical_hour_end,
    last_seen_at
   FROM monitoring.user_risk_profiles p
  ORDER BY risk_score DESC, consecutive_high_risk DESC;

CREATE OR REPLACE VIEW processes.executions_json AS
 SELECT jsonb_agg(process_exec) AS jsonb_agg
   FROM ( SELECT jsonb_build_object('process_id', p.process_id, 'execution_key', e.execution_key, 'status', e.status, 'started_at', e.started_at, 'completed_at', e.completed_at, 'steps', jsonb_agg(jsonb_build_object('step_id', s.row_id, 'status', e.status, 'started_at', e.started_at, 'completed_at', e.completed_at, 'duration_ms', e.duration_ms, 'row_count', e.row_count) ORDER BY s.step_order)) AS process_exec
           FROM ((processes.process p
             JOIN processes.steps s ON ((s.process_id = p.row_id)))
             LEFT JOIN processes.executions e ON (((e.process_id = p.row_id) AND (e.step_id = s.id))))
          GROUP BY p.process_id, e.execution_key, e.status, e.started_at, e.completed_at) t;

CREATE OR REPLACE VIEW processes.v_processes_steps AS
 SELECT o.activity,
    o.api_key,
    o.api_url,
    o.organization_name,
    o.row_id AS org_id,
    p.category,
    p.schedule_type,
    p.expected_duration_ms AS process_expected_duration_ms,
    p.process_name,
    p.schedule_expr,
    p.process_id,
    p.description,
    s.id AS step_id,
    s.step_name,
    s.step_order,
    s.step_type,
    s.step_query,
    s.expected_ms AS step_expected_ms,
    s.expected_rows AS step_expected_rows
   FROM ((processes.organization o
     JOIN processes.process p ON ((p.organization_id = o.row_id)))
     JOIN processes.steps s ON ((s.process_id = p.row_id)));

CREATE OR REPLACE VIEW processes.v_processes_steps_executions AS
 SELECT o.activity,
    o.api_key,
    o.api_url,
    o.organization_name,
    o.row_id AS org_id,
    p.category,
    p.schedule_type,
    p.expected_duration_ms AS process_expected_duration_ms,
    p.process_name,
    p.schedule_expr,
    p.process_id,
    p.description,
    s.step_name,
    s.step_order,
    s.step_type,
    s.expected_ms AS step_expected_ms,
    s.expected_rows AS step_expected_rows,
    e.row_id,
    e.status,
    e.started_at,
    e.completed_at,
    e.duration_ms,
    e.row_count,
    e.error_message
   FROM (((processes.organization o
     JOIN processes.process p ON ((p.organization_id = o.row_id)))
     JOIN processes.steps s ON ((s.process_id = p.row_id)))
     LEFT JOIN processes.executions e ON ((e.process_id = p.row_id)));

CREATE OR REPLACE VIEW processes.v_processes_steps_json AS
 SELECT org_id,
    organization_name,
    api_key,
    api_url,
    process_id,
    jsonb_build_object('id', process_id, 'name', process_name, 'description', description, 'category', category, 'schedule_type', schedule_type, 'schedule_expr', schedule_expr, 'expected_duration_ms', process_expected_duration_ms, 'steps', steps) AS processes
   FROM ( SELECT v.api_url,
            v.api_key,
            v.org_id,
            v.organization_name,
            v.process_id,
            v.process_name,
            v.description,
            v.category,
            v.schedule_type,
            v.schedule_expr,
            v.process_expected_duration_ms,
            jsonb_agg(jsonb_build_object('name', v.step_name, 'type', v.step_type, 'order', v.step_order, 'expected_ms', v.step_expected_ms, 'expected_rows', v.step_expected_rows) ORDER BY v.step_order) AS steps
           FROM processes.v_processes_steps v
          GROUP BY v.api_url, v.api_key, v.org_id, v.organization_name, v.process_id, v.process_name, v.description, v.category, v.schedule_type, v.schedule_expr, v.process_expected_duration_ms) t;

CREATE OR REPLACE VIEW processes.v_servers_processes AS
 SELECT s.row_id,
    s.server,
    s.servername,
    s.database,
    s.username,
    s.password,
    s.driver,
    s.is_active,
    s.db_vendor AS vendor,
    s.port,
    s.auth_type,
    pr.row_id AS process_id,
    s.service_name
   FROM (metrics.servers s
     JOIN processes.process pr ON ((pr.server_id = s.row_id)));

CREATE OR REPLACE VIEW public.v_detection_coverage AS
 SELECT v.slug AS vendor,
    d.code AS domain,
    count(DISTINCT rc.id) AS applicable_rcs,
    count(DISTINCT dp.id) AS with_detection,
    round((((count(DISTINCT dp.id))::numeric / (NULLIF(count(DISTINCT rc.id), 0))::numeric) * (100)::numeric), 1) AS detection_pct
   FROM ((((public.root_causes rc
     JOIN public.issues i ON ((i.id = rc.issue_id)))
     JOIN public.domains d ON ((d.id = i.domain_id)))
     CROSS JOIN public.vendors v)
     LEFT JOIN public.detection_paths dp ON (((dp.root_cause_id = rc.id) AND (dp.vendor_id = v.id) AND (dp.is_active = true))))
  WHERE (rc.vendors_applicable @> ARRAY[(v.slug)::text])
  GROUP BY v.slug, d.code
  ORDER BY v.slug, d.code;

CREATE OR REPLACE VIEW public.v_open_detections AS
 SELECT de.id AS event_id,
    de.detected_at,
    de.target_host,
    de.target_database,
    de.severity,
    de.confidence,
    de.trigger_source,
    v.slug AS vendor,
    i.name AS issue_name,
    rc.name AS root_cause_name,
    ra.status AS resolution_status,
    ra.proposed_at AS resolution_proposed_at
   FROM ((((public.detection_events de
     JOIN public.root_causes rc ON ((rc.id = de.root_cause_id)))
     JOIN public.issues i ON ((i.id = rc.issue_id)))
     JOIN public.vendors v ON ((v.id = de.vendor_id)))
     LEFT JOIN public.resolution_actions ra ON ((ra.detection_event_id = de.id)))
  WHERE (de.resolved = false)
  ORDER BY de.detected_at DESC;

CREATE OR REPLACE VIEW public.v_root_causes AS
 SELECT rc.id AS root_cause_pk,
    d.code AS domain_code,
    d.name AS domain_name,
    dt.slug AS database_type,
    i.issue_id,
    i.name AS issue_name,
    rc.root_cause_id,
    rc.root_cause_number,
    rc.name AS root_cause_name,
    rc.description,
    rc.topics,
    rc.vendors_applicable,
    rc.vendor_considerations,
    rc.vendor_descriptions,
    rc.search_text
   FROM (((public.root_causes rc
     JOIN public.issues i ON ((i.id = rc.issue_id)))
     JOIN public.domains d ON ((d.id = i.domain_id)))
     JOIN public.database_types dt ON ((dt.id = i.database_type_id)));

CREATE OR REPLACE VIEW rootcause.v_category_definitions AS
 WITH latest_results AS (
         SELECT DISTINCT ON (general_metric_metadata_results_old.metric_name) general_metric_metadata_results_old.metric_name AS root_cause_id,
            general_metric_metadata_results_old.metric_metadata_vs_expected,
            general_metric_metadata_results_old.metric_metadata,
                CASE
                    WHEN ((general_metric_metadata_results_old.metric_metadata_vs_expected IS NOT NULL) AND ((general_metric_metadata_results_old.metric_metadata_vs_expected ->> 'matched'::text) IS NOT NULL)) THEN 'red'::text
                    WHEN ((general_metric_metadata_results_old.metric_metadata IS NOT NULL) AND ((general_metric_metadata_results_old.metric_metadata)::text <> '[]'::text) AND ((general_metric_metadata_results_old.metric_metadata)::text <> ''::text)) THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light,
                CASE
                    WHEN ((general_metric_metadata_results_old.metric_metadata_vs_expected IS NOT NULL) AND ((general_metric_metadata_results_old.metric_metadata_vs_expected ->> 'matched'::text) IS NOT NULL)) THEN 2
                    WHEN ((general_metric_metadata_results_old.metric_metadata IS NOT NULL) AND ((general_metric_metadata_results_old.metric_metadata)::text <> '[]'::text) AND ((general_metric_metadata_results_old.metric_metadata)::text <> ''::text)) THEN 1
                    ELSE 0
                END AS sev
           FROM monitoring.general_metric_metadata_results_old
          ORDER BY general_metric_metadata_results_old.metric_name, general_metric_metadata_results_old.entry_date DESC
        ), issue_status AS (
         SELECT rc.issue_id,
            COALESCE(max(lr.sev), 0) AS sev,
                CASE COALESCE(max(lr.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM (rootcause.root_causes rc
             LEFT JOIN latest_results lr ON (((lr.root_cause_id)::text = (rc.root_cause_id)::text)))
          GROUP BY rc.issue_id
        ), area_status AS (
         SELECT i.domain_code,
            i.area_code,
            COALESCE(max(ist.sev), 0) AS sev,
                CASE COALESCE(max(ist.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM (rootcause.issues i
             LEFT JOIN issue_status ist ON (((ist.issue_id)::text = (i.issue_id)::text)))
          GROUP BY i.domain_code, i.area_code
        ), domain_status AS (
         SELECT area_status.domain_code,
            COALESCE(max(area_status.sev), 0) AS sev,
                CASE COALESCE(max(area_status.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM area_status
          GROUP BY area_status.domain_code
        ), domain_data AS (
         SELECT d.category_id AS id,
            d.name,
                CASE d.code
                    WHEN 'SEC'::text THEN 'ShieldLock'::text
                    WHEN 'PERF'::text THEN 'Speedometer2'::text
                    WHEN 'HLTH'::text THEN 'HeartPulse'::text
                    ELSE 'Diagram3'::text
                END AS icon,
            COALESCE(ds.sev, 0) AS severity,
            COALESCE(ds.traffic_light, 'green'::text) AS status,
            COALESCE(ds.traffic_light, 'green'::text) AS "trafficLight",
            ( SELECT count(DISTINCT i2.issue_id) AS count
                   FROM rootcause.issues i2
                  WHERE ((i2.domain_code)::text = (d.code)::text)) AS "advisoryCount"
           FROM (rootcause.domains d
             LEFT JOIN domain_status ds ON (((ds.domain_code)::text = (d.code)::text)))
          WHERE (d.is_enabled = true)
        ), area_data AS (
         SELECT DISTINCT ((d.category_id)::text || (a.category_id)::text) AS id,
            a.name,
                CASE a.code
                    WHEN 'ACC'::text THEN 'ShieldCheck'::text
                    WHEN 'AU'::text THEN 'ShieldCheck'::text
                    WHEN 'AUTH'::text THEN 'ShieldCheck'::text
                    WHEN 'AZ'::text THEN 'Key'::text
                    WHEN 'AUTHZ'::text THEN 'Key'::text
                    WHEN 'NET'::text THEN 'Globe'::text
                    WHEN 'INJ'::text THEN 'LockFill'::text
                    WHEN 'ENC'::text THEN 'LockFill'::text
                    WHEN 'LOG'::text THEN 'FileEarmarkText'::text
                    WHEN 'AUD'::text THEN 'ShieldCheck'::text
                    WHEN 'AUDIT'::text THEN 'ShieldCheck'::text
                    WHEN 'ATK'::text THEN 'ShieldExclamation'::text
                    WHEN 'CMD'::text THEN 'Terminal'::text
                    WHEN 'CFG'::text THEN 'GearWideConnected'::text
                    WHEN 'DAT'::text THEN 'Database'::text
                    WHEN 'DATA'::text THEN 'Database'::text
                    WHEN 'PRI'::text THEN 'SortNumericDown'::text
                    WHEN 'PAT'::text THEN 'Search'::text
                    WHEN 'VS'::text THEN 'VectorPen'::text
                    WHEN 'QE'::text THEN 'Lightning'::text
                    WHEN 'QRY'::text THEN 'CodeSlash'::text
                    WHEN 'IX'::text THEN 'ListCheck'::text
                    WHEN 'CONN'::text THEN 'Link'::text
                    WHEN 'MEM'::text THEN 'Memory'::text
                    WHEN 'LM'::text THEN 'Lock'::text
                    WHEN 'SYS'::text THEN 'Pc'::text
                    WHEN 'MNT'::text THEN 'Wrench'::text
                    WHEN 'IDX'::text THEN 'ListCheck'::text
                    WHEN 'IO'::text THEN 'HddStack'::text
                    WHEN 'LAT'::text THEN 'Stopwatch'::text
                    WHEN 'OPT'::text THEN 'Sliders'::text
                    WHEN 'WRT'::text THEN 'PencilSquare'::text
                    WHEN 'THRU'::text THEN 'Speedometer'::text
                    WHEN 'CD'::text THEN 'ArrowRepeat'::text
                    WHEN 'AD'::text THEN 'App'::text
                    WHEN 'DM'::text THEN 'DatabaseGear'::text
                    ELSE 'Shield'::text
                END AS icon,
            COALESCE(ast.sev, 0) AS severity,
            COALESCE(ast.traffic_light, 'green'::text) AS status,
            COALESCE(ast.traffic_light, 'green'::text) AS "trafficLight"
           FROM (((rootcause.areas a
             JOIN rootcause.issues i ON (((i.area_code)::text = (a.code)::text)))
             JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
             LEFT JOIN area_status ast ON ((((ast.domain_code)::text = (i.domain_code)::text) AND ((ast.area_code)::text = (a.code)::text))))
          WHERE (d.is_enabled = true)
        ), issue_detail_files AS (
         SELECT i.issue_id,
            (ARRAY[((i.issue_id)::text || '.json'::text)] || COALESCE(( SELECT array_agg(DISTINCT ((rc.root_cause_id)::text || '.json'::text) ORDER BY ((rc.root_cause_id)::text || '.json'::text)) AS array_agg
                   FROM rootcause.root_causes rc
                  WHERE ((rc.issue_id)::text = (i.issue_id)::text)), ARRAY[]::text[])) AS detail_files
           FROM rootcause.issues i
        ), category_data AS (
         SELECT (((d.category_id)::text || (a.category_id)::text) || (i.category_id)::text) AS id,
            i.name,
                CASE
                    WHEN ((i.name)::text ~~* '%injection%'::text) THEN 'BugFill'::text
                    WHEN (((i.name)::text ~~* '%login%'::text) OR ((i.name)::text ~~* '%auth%'::text) OR ((i.name)::text ~~* '%account%'::text)) THEN 'Lock'::text
                    WHEN (((i.name)::text ~~* '%encrypt%'::text) OR ((i.name)::text ~~* '%tls%'::text) OR ((i.name)::text ~~* '%ssl%'::text)) THEN 'LockFill'::text
                    WHEN (((i.name)::text ~~* '%privilege%'::text) OR ((i.name)::text ~~* '%permission%'::text) OR ((i.name)::text ~~* '%access%'::text)) THEN 'Key'::text
                    WHEN (((i.name)::text ~~* '%anomal%'::text) OR ((i.name)::text ~~* '%suspicious%'::text)) THEN 'ExclamationTriangle'::text
                    WHEN (((i.name)::text ~~* '%audit%'::text) OR ((i.name)::text ~~* '%log%'::text)) THEN 'FileEarmarkText'::text
                    WHEN (((i.name)::text ~~* '%network%'::text) OR ((i.name)::text ~~* '%remote%'::text) OR ((i.name)::text ~~* '%connection%'::text)) THEN 'Globe'::text
                    WHEN (((i.name)::text ~~* '%query%'::text) OR ((i.name)::text ~~* '%execution%'::text)) THEN 'Lightning'::text
                    WHEN ((i.name)::text ~~* '%index%'::text) THEN 'ListCheck'::text
                    WHEN (((i.name)::text ~~* '%lock%'::text) OR ((i.name)::text ~~* '%block%'::text) OR ((i.name)::text ~~* '%deadlock%'::text)) THEN 'Lock'::text
                    WHEN (((i.name)::text ~~* '%memory%'::text) OR ((i.name)::text ~~* '%buffer%'::text)) THEN 'Memory'::text
                    WHEN (((i.name)::text ~~* '%disk%'::text) OR ((i.name)::text ~~* '%io%'::text) OR ((i.name)::text ~~* '%storage%'::text)) THEN 'HddStack'::text
                    WHEN ((i.name)::text ~~* '%cpu%'::text) THEN 'Cpu'::text
                    WHEN ((i.name)::text ~~* '%backup%'::text) THEN 'CloudUpload'::text
                    WHEN ((i.name)::text ~~* '%transact%'::text) THEN 'ArrowLeftRight'::text
                    WHEN (((i.name)::text ~~* '%config%'::text) OR ((i.name)::text ~~* '%setting%'::text)) THEN 'GearWideConnected'::text
                    WHEN (((i.name)::text ~~* '%data%'::text) OR ((i.name)::text ~~* '%sensitive%'::text) OR ((i.name)::text ~~* '%pii%'::text)) THEN 'ShieldCheck'::text
                    ELSE 'ExclamationTriangle'::text
                END AS icon,
            COALESCE(ist.sev, 0) AS severity,
            COALESCE(ist.traffic_light, 'green'::text) AS status,
            COALESCE(ist.traffic_light, 'green'::text) AS "trafficLight",
            idf.detail_files AS "detailFiles"
           FROM ((((rootcause.issues i
             JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
             JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
             JOIN issue_detail_files idf ON (((idf.issue_id)::text = (i.issue_id)::text)))
             LEFT JOIN issue_status ist ON (((ist.issue_id)::text = (i.issue_id)::text)))
          WHERE ((d.is_enabled = true) AND (EXISTS ( SELECT 1
                   FROM (rootcause.v_rootcauses vrc
                     JOIN metrics.servers s ON ((s.db_vendor = (vrc.vendor_name)::text)))
                  WHERE ((vrc.issue_id)::text = (i.issue_id)::text))))
        )
 SELECT json_build_object('adminConsoleURL', 'http://localhost:8000/admin', 'domains', ( SELECT json_agg(row_to_json(d.*) ORDER BY d.id) AS json_agg
           FROM domain_data d), 'areas', ( SELECT json_agg(row_to_json(a.*) ORDER BY a.id) AS json_agg
           FROM area_data a), 'categories', ( SELECT json_agg(row_to_json(c.*) ORDER BY c.id) AS json_agg
           FROM category_data c), 'servers', ( SELECT json_agg(DISTINCT s.server ORDER BY s.server) AS json_agg
           FROM metrics.servers s
          WHERE (s.is_active = true))) AS result;

CREATE OR REPLACE VIEW rootcause.v_issue_decision_tree AS
 SELECT t.issue_id,
    t.vendor_slug,
    t.name AS tree_name,
    n.id AS node_id,
    n.parent_node_id,
    n.tier,
    n.sequence,
    n.gate_label,
    n.gate_question,
    n.gate_detection_step_id,
    ds.name AS detection_step_name,
    (ds.expected ->> 'condition'::text) AS gate_condition,
    n.on_match_rc_id,
    rc.name AS on_match_rc_name,
    n.on_match_terminate,
    n.on_match_drill_rc_ids,
    n.notes,
    n.is_active,
    n.on_no_match_terminate
   FROM (((rootcause.issue_decision_trees t
     JOIN rootcause.issue_decision_tree_nodes n ON ((n.tree_id = t.id)))
     LEFT JOIN rootcause.detection_steps ds ON ((ds.id = n.gate_detection_step_id)))
     LEFT JOIN rootcause.root_causes rc ON (((rc.root_cause_id)::text = (n.on_match_rc_id)::text)))
  WHERE (t.is_active AND n.is_active)
  ORDER BY t.issue_id, t.vendor_slug, n.tier, n.sequence;

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
    raq.query_resultset,
    rc.risk_level
   FROM (((rootcause.v_rootcauses rc
     JOIN rootcause.rootcause_alert_query raq ON ((raq.root_cause_id = (rc.root_cause_id)::text)))
     JOIN rootcause.rootcause_alert_query_result_server raqrs ON ((raqrs.root_cause_id = (rc.root_cause_id)::text)))
     JOIN metrics.servers s ON ((s.server = raqrs.server)))
  WHERE ((lower((rc.vendor_name)::text) = lower(s.db_vendor)) OR (lower((rc.vendor_name)::text) = 'sqlserver'::text));

CREATE OR REPLACE VIEW siem.v_ips_blocked AS
 SELECT attack_name,
    COALESCE(intrusion_type, ''::text) AS intrusion_type,
    severity,
    sum(count) AS total
   FROM siem.fortianalyzer_ips_events
  WHERE (action = 'blocked'::text)
  GROUP BY attack_name, intrusion_type, severity
  ORDER BY
        CASE severity
            WHEN 'critical'::text THEN 1
            WHEN 'high'::text THEN 2
            WHEN 'medium'::text THEN 3
            ELSE 4
        END, (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_detected AS
 SELECT attack_name,
    cve_id,
    intrusion_type,
    severity,
    action,
    sum(count) AS total
   FROM siem.fortianalyzer_ips_events
  WHERE (severity = ANY (ARRAY['critical'::text, 'high'::text, 'medium'::text]))
  GROUP BY attack_name, cve_id, intrusion_type, severity, action
  ORDER BY
        CASE severity
            WHEN 'critical'::text THEN 1
            WHEN 'high'::text THEN 2
            WHEN 'medium'::text THEN 3
            ELSE 4
        END, (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_http_attacks AS
 SELECT attack_name,
    severity,
    sum(count) AS total
   FROM siem.fortianalyzer_ips_events
  WHERE (upper(protocol) = ANY (ARRAY['HTTP'::text, 'HTTPS'::text]))
  GROUP BY attack_name, severity
  ORDER BY
        CASE severity
            WHEN 'critical'::text THEN 1
            WHEN 'high'::text THEN 2
            WHEN 'medium'::text THEN 3
            ELSE 4
        END, (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_monitored AS
 SELECT attack_name,
    COALESCE(intrusion_type, ''::text) AS intrusion_type,
    severity,
    sum(count) AS total
   FROM siem.fortianalyzer_ips_events
  WHERE (action = 'monitored'::text)
  GROUP BY attack_name, intrusion_type, severity
  ORDER BY
        CASE severity
            WHEN 'critical'::text THEN 1
            WHEN 'high'::text THEN 2
            WHEN 'medium'::text THEN 3
            WHEN 'low'::text THEN 4
            WHEN 'info'::text THEN 5
            ELSE 6
        END, (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_severity_summary AS
 SELECT severity,
    sum(count) AS total,
    round((((sum(count))::numeric * 100.0) / sum(sum(count)) OVER ()), 2) AS pct
   FROM siem.fortianalyzer_ips_events
  GROUP BY severity
  ORDER BY
        CASE severity
            WHEN 'critical'::text THEN 1
            WHEN 'high'::text THEN 2
            WHEN 'medium'::text THEN 3
            WHEN 'low'::text THEN 4
            WHEN 'info'::text THEN 5
            ELSE 6
        END;

CREATE OR REPLACE VIEW siem.v_ips_sources AS
 SELECT (src_ip)::text AS source_ip,
    sum(count) FILTER (WHERE (severity = 'critical'::text)) AS critical,
    sum(count) FILTER (WHERE (severity = 'high'::text)) AS high,
    sum(count) FILTER (WHERE (severity = 'medium'::text)) AS medium,
    sum(count) AS total,
    round((((sum(count))::numeric * 100.0) / sum(sum(count)) OVER ()), 2) AS pct_of_total
   FROM siem.fortianalyzer_ips_events
  WHERE (src_ip IS NOT NULL)
  GROUP BY src_ip
  ORDER BY (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_timeline AS
 SELECT date_trunc('hour'::text, event_time) AS hour_bucket,
    sum(count) FILTER (WHERE (severity = 'critical'::text)) AS critical,
    sum(count) FILTER (WHERE (severity = 'high'::text)) AS high,
    sum(count) FILTER (WHERE (severity = 'medium'::text)) AS medium
   FROM siem.fortianalyzer_ips_events
  WHERE (severity = ANY (ARRAY['critical'::text, 'high'::text, 'medium'::text]))
  GROUP BY (date_trunc('hour'::text, event_time))
  ORDER BY (date_trunc('hour'::text, event_time));

CREATE OR REPLACE VIEW siem.v_ips_type_summary AS
 SELECT COALESCE(intrusion_type, 'Unknown'::text) AS intrusion_type,
    sum(count) AS total
   FROM siem.fortianalyzer_ips_events
  GROUP BY intrusion_type
  ORDER BY (sum(count)) DESC;

CREATE OR REPLACE VIEW siem.v_ips_victims AS
 SELECT (dst_ip)::text AS victim_ip,
    sum(count) FILTER (WHERE (severity = 'critical'::text)) AS critical,
    sum(count) FILTER (WHERE (severity = 'high'::text)) AS high,
    sum(count) FILTER (WHERE (severity = 'medium'::text)) AS medium,
    sum(count) AS total,
    round((((sum(count))::numeric * 100.0) / sum(sum(count)) OVER ()), 2) AS pct_of_total
   FROM siem.fortianalyzer_ips_events
  WHERE (dst_ip IS NOT NULL)
  GROUP BY dst_ip
  ORDER BY (sum(count)) DESC;

REFRESH MATERIALIZED VIEW monitoring.v_sensitive_columns;
