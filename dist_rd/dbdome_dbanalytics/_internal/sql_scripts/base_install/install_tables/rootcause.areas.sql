-- Idempotent install for rootcause.areas
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE TABLE IF NOT EXISTS rootcause.areas (
    code character varying(10) NOT NULL,
    database_type_code character varying(10) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    category_id character(4)
);

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.areas);
COPY _stg_load (code, database_type_code, name, description, created_at, is_enabled, category_id) FROM stdin;
QRY	DOC	Queries	\N	2026-02-23 20:18:30.380836	t	a012
DOC	DOC	Document Operations	\N	2026-02-23 20:18:30.380838	t	a014
SHD	DOC	Sharding	\N	2026-02-23 20:18:30.380838	t	a015
CON	DOC	Consistency	\N	2026-02-23 20:18:30.380839	t	a016
WRT	DOC	Write Operations	\N	2026-02-23 20:18:30.38084	t	a018
KEY	KV	Key Management	\N	2026-02-23 20:18:30.380851	t	a019
STG	DOC	Storage	\N	2026-02-23 20:18:30.380842	t	a013
HA	DOC	High Availability	\N	2026-02-23 20:18:30.380843	t	a014
CLU	DOC	Clustering	\N	2026-02-23 20:18:30.380843	t	a015
MNT	DOC	Maintenance	\N	2026-02-23 20:18:30.380844	t	a016
UPG	DOC	Upgrades	\N	2026-02-23 20:18:30.380845	t	a017
PERS	KV	Persistence	\N	2026-02-23 20:18:30.380857	t	a018
REP	KV	Replication	\N	2026-02-23 20:18:30.380858	t	a019
TOPO	KV	Topology	\N	2026-02-23 20:18:30.380858	t	a020
STOR	KV	Storage	\N	2026-02-23 20:18:30.380859	t	a021
BACKUP	KV	Backup & Recovery	\N	2026-02-23 20:18:30.380859	t	a022
HA	KV	High Availability	\N	2026-02-23 20:18:30.38086	t	a023
MAINT	KV	Maintenance	\N	2026-02-23 20:18:30.380861	t	a024
UPGR	KV	Upgrades	\N	2026-02-23 20:18:30.380861	t	a025
STG	VEC	Storage	\N	2026-02-23 20:18:30.380871	t	a026
REP	VEC	Replication	\N	2026-02-23 20:18:30.380872	t	a027
BKP	VEC	Backup & Recovery	\N	2026-02-23 20:18:30.380872	t	a028
RES	VEC	Resource Management	\N	2026-02-23 20:18:30.380873	t	a029
MNT	VEC	Maintenance	\N	2026-02-23 20:18:30.380874	t	a030
UPG	VEC	Upgrades	\N	2026-02-23 20:18:30.380874	t	a031
SYS	VEC	System	\N	2026-02-23 20:18:30.380876	t	a033
EVICT	KV	Eviction	\N	2026-02-23 20:18:30.380852	t	a021
THRU	KV	Throughput	\N	2026-02-23 20:18:30.380853	t	a022
LAT	KV	Latency	\N	2026-02-23 20:18:30.380853	t	a023
CONN	KV	Connection Management	\N	2026-02-23 20:18:30.380854	t	a024
CLUST	KV	Clustering	\N	2026-02-23 20:18:30.380855	t	a026
PUBSUB	KV	Pub/Sub	\N	2026-02-23 20:18:30.380856	t	a027
TTL	KV	TTL & Expiry	\N	2026-02-23 20:18:30.380856	t	a028
QRY	VEC	Queries	\N	2026-02-23 20:18:30.380867	t	a030
ING	VEC	Ingestion	\N	2026-02-23 20:18:30.380868	t	a031
DIM	VEC	Dimensionality	\N	2026-02-23 20:18:30.380869	t	a033
OPT	VEC	Optimization	\N	2026-02-23 20:18:30.380869	t	a034
HYB	VEC	Hybrid Search	\N	2026-02-23 20:18:30.38087	t	a035
SCL	VEC	Scalability	\N	2026-02-23 20:18:30.380871	t	a036
DATA	KV	Data Management	\N	2026-02-23 20:18:30.380855	t	a033
INT	VEC	Integration	\N	2026-02-23 20:18:30.380875	t	a032
ACC	SQL	ACC	\N	2026-04-03 08:09:22.400373	t	a031
VS	SQL	Vector Search	\N	2026-02-23 20:18:30.380824	t	a032
RP	SQL	Resource Pooling	\N	2026-02-23 20:18:30.380825	t	a002
SM	SQL	Schema Management	\N	2026-02-23 20:18:30.380826	t	a003
HA	SQL	High Availability	\N	2026-02-23 20:18:30.380826	t	a004
DM	SQL	Data Modeling	\N	2026-02-23 20:18:30.380827	t	a005
LM	SQL	Lock Management	\N	2026-02-23 20:18:30.380827	t	a006
SJ	SQL	Schema & JSON	\N	2026-02-23 20:18:30.380828	t	a007
UP	SQL	Upgrades	\N	2026-02-23 20:18:30.380829	t	a008
CD	SQL	Change Detection	\N	2026-02-23 20:18:30.380829	t	a009
AD	SQL	Application & Driver	\N	2026-02-23 20:18:30.38083	t	a010
AUTH	DOC	Authentication	\N	2026-02-23 20:18:30.380846	t	a011
AUTHZ	DOC	Authorization	\N	2026-02-23 20:18:30.380847	t	a012
ENC	DOC	Encryption	\N	2026-02-23 20:18:30.380847	t	a013
AUD	DOC	Auditing	\N	2026-02-23 20:18:30.380848	t	a014
NET	DOC	Networking	\N	2026-02-23 20:18:30.380849	t	a015
INJ	DOC	Injection & Exploits	\N	2026-02-23 20:18:30.380849	t	a016
DAT	DOC	Data Modeling	\N	2026-02-23 20:18:30.38085	t	a017
AUTH	KV	Authentication	\N	2026-02-23 20:18:30.380862	t	a018
AUTHZ	KV	Authorization	\N	2026-02-23 20:18:30.380863	t	a019
NET	KV	Networking	\N	2026-02-23 20:18:30.380863	t	a020
ENC	KV	Encryption	\N	2026-02-23 20:18:30.380864	t	a021
CMD	KV	Commands	\N	2026-02-23 20:18:30.380864	t	a022
INJ	KV	Injection & Exploits	\N	2026-02-23 20:18:30.380865	t	a023
AUDIT	KV	Auditing	\N	2026-02-23 20:18:30.380866	t	a024
AUTH	VEC	Authentication	\N	2026-02-23 20:18:30.380876	t	a025
ACC	VEC	Access Control	\N	2026-02-23 20:18:30.380877	t	a026
DAT	VEC	Data Modeling	\N	2026-02-23 20:18:30.380877	t	a027
ATK	VEC	Attack Prevention	\N	2026-02-23 20:18:30.380878	t	a028
NET	VEC	Networking	\N	2026-02-23 20:18:30.380879	t	a029
BAK	DOC	Backup & Recovery	\N	2026-02-23 20:18:30.380841	t	a011
REP	DOC	Replication	\N	2026-02-23 20:18:30.380842	t	a012
PRI	SQL	Priority & Scheduling	\N	2026-02-23 20:18:30.380836	t	a009
QE	SQL	Query Execution	\N	2026-02-23 20:18:30.380811	t	a001
IX	SQL	Indexing	\N	2026-02-23 20:18:30.380817	t	a002
LC	SQL	Locking & Concurrency	\N	2026-02-23 20:18:30.380818	t	a003
CPU	SQL	CPU	\N	2026-02-23 20:18:30.380819	t	a004
IO	SQL	I/O	\N	2026-02-23 20:18:30.38082	t	a006
CN	SQL	Connection Management	\N	2026-02-23 20:18:30.380821	t	a007
CE	SQL	Consistency & Errors	\N	2026-02-23 20:18:30.380822	t	a008
PL	SQL	Partitioning & Large Tables	\N	2026-02-23 20:18:30.380822	t	a009
TX	SQL	Transactions	\N	2026-02-23 20:18:30.380823	t	a010
BR	SQL	Backup & Recovery	\N	2026-02-23 20:18:30.380824	t	a001
AU	SQL	Authentication	\N	2026-02-23 20:18:30.380831	t	a001
AZ	SQL	Authorization	\N	2026-02-23 20:18:30.380831	t	a002
ENC	SQL	Encryption	\N	2026-02-23 20:18:30.380832	t	a003
MEM	SQL	Memory	\N	2026-02-23 20:18:30.38082	t	a034
IDX	DOC	Indexing	\N	2026-02-23 20:18:30.380837	t	a035
MEM	DOC	Memory	\N	2026-02-23 20:18:30.38084	t	a036
LOG	DOC	Logging	\N	2026-02-23 20:18:30.380845	t	a037
LOG	VEC	Logging	\N	2026-02-23 20:18:30.380879	t	a038
MEM	KV	Memory	\N	2026-02-23 20:18:30.380851	t	a039
IDX	VEC	Indexing	\N	2026-02-23 20:18:30.380866	t	a040
MEM	VEC	Memory	\N	2026-02-23 20:18:30.380868	t	a041
AUD	SQL	Auditing	\N	2026-02-23 20:18:30.380833	t	a004
NET	SQL	Networking	\N	2026-02-23 20:18:30.380833	t	a005
CFG	SQL	Configuration	\N	2026-02-23 20:18:30.380834	t	a006
INJ	SQL	Injection & Exploits	\N	2026-02-23 20:18:30.380834	t	a007
PAT	SQL	Patterns	\N	2026-02-23 20:18:30.380835	t	a008
AUTHZ	SQL	Authorization	Authorization for SQL databases: roles, privileges and grants.	2026-06-10 10:41:19.763449	t	a031
\.
INSERT INTO rootcause.areas (code, database_type_code, name, description, created_at, is_enabled, category_id)
SELECT code, database_type_code, name, description, created_at, is_enabled, category_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.areas);
DROP TABLE _stg_load;


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'areas'
          AND con.conname = 'uq_area_code_dbtype') THEN
        ALTER TABLE ONLY rootcause.areas
    ADD CONSTRAINT uq_area_code_dbtype PRIMARY KEY (code, database_type_code);
    END IF;
END $do$;
