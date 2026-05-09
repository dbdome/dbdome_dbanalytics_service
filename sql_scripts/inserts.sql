
CREATE OR REPLACE VIEW rootcause.v_rootcauses
 AS
 SELECT DISTINCT d.code AS domain_code,
    d.name AS domain_name,
    a.code AS area_code,
    a.name AS area_name,
    i.name AS issue_name,
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
    v.name AS vendor_name,
    rpst.risk_level
   FROM ((((((((((rootcause.issues i
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
  WHERE ((d.is_enabled IS TRUE) AND (a.is_enabled IS TRUE));

ALTER TABLE IF EXISTS rootcause.v_rootcauses
    OWNER TO enterprisedb;


select distinct -- View: monitoring.v_sec_sql_au_001_rc03

-- DROP VIEW monitoring.v_sec_sql_au_001_rc03;
CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc03
 AS
 SELECT (j.value ->> 'sa_not_renamed'::text) AS sa_not_renamed,
    (j.value ->> 'name'::text) AS name,
    (j.value ->> 'port'::text) AS port,
    (j.value ->> 'state_desc'::text) AS state_desc,
    (j.value ->> 'protocol_desc'::text) AS protocol_desc,
    (j.value ->> 'is_dynamic_port'::text) AS is_dynamic_port,
    (j.value ->> 'is_admin_endpoint'::text) AS is_admin_endpoint,
    r.server,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-AU-001-RC03'::text);


ALTER TABLE IF EXISTS monitoring.v_sec_sql_au_001_rc03
    OWNER TO enterprisedb;
select* from rootcause.v_root_cause_alerts

create table config.webook_alerts 
(
	row_id  serial primary key , 
	metric_type varchar(50) , 
	send_mail_alert  boolean  not null default true , 
	send_siem_alert  boolean  not null default true , 
	send_diagnosis_evidence boolean  not null default true  , 
	entry_date  timestamp  not null default   Now()
)


insert into config.webook_alerts ( metric_type , send_mail_alert , send_siem_alert , send_diagnosis_evidence ) 
select 'Security' , true , true , true
select * from config.webook_alerts

