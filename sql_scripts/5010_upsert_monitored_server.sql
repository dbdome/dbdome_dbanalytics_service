-- PROCEDURE: metrics.upsert_monitored_server(text, text, text, text, text, text, text, text, integer, text)

-- DROP PROCEDURE IF EXISTS metrics.upsert_monitored_server(text, text, text, text, text, text, text, text, integer, text);

CREATE OR REPLACE PROCEDURE metrics.upsert_monitored_server(
	IN p_ip_address text,
	IN p_server_name text,
	IN p_db_vendor text,
	IN p_db_version text,
	IN p_auth_type text,
	IN p_username text,
	IN p_password text,
	IN p_service_name text,
	IN p_port integer,
	IN p_add_modify_delete text)
LANGUAGE 'plpgsql'
AS $BODY$
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
$BODY$;
ALTER PROCEDURE metrics.upsert_monitored_server(text, text, text, text, text, text, text, text, integer, text)
    OWNER TO postgres;

