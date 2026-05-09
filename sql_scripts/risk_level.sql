create table rootcause.risk_level
(
	row_id serial primary key not null  , 
	risk_level char(10) not null  , 
	is_active boolean not null default true ,
	entry_date timestamp not null default Now()
)
insert into rootcause.risk_level  ( risk_level )
select distinct risk_level from rootcause.resolution_steps