create table alerts.alert_log
(
	row_id serial primary key not null , 
	server varchar(100) not null , 
	root_cause_id varchar(100)  not null  , 
	risk_level  varchar(50) not null , 
	metadata jsonb not null  , 
	entry_date timestamp not null default Now()
	
)
