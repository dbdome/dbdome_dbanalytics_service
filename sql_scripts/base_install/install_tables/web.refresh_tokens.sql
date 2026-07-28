-- Idempotent install for web.refresh_tokens
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS web;

CREATE SEQUENCE IF NOT EXISTS web.refresh_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS web.refresh_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token character varying(500) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE web.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('web.refresh_tokens_id_seq'::regclass);
ALTER SEQUENCE web.refresh_tokens_id_seq OWNED BY web.refresh_tokens.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE web.refresh_tokens);
COPY _stg_load (id, user_id, token, expires_at, created_at) FROM stdin;
1	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzg2OTYzODF9.24EDCnl8zAc6mJfjdPqSrYjjQeAoxbfpAv3zw_-K1FA	2026-05-13 21:19:41.528+03	2026-04-13 21:19:41.528152+03
7	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkxNTkxOTh9.LYIdf4wRg-UA9lxFd_6DjEy0r13Mwt5x2yyUKher2Fs	2026-05-19 05:53:18.252443+03	2026-04-19 05:53:18.251296+03
12	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkyNDE2NzB9.X-zyx8LXjsD-Z_l2sfteuVApAlQHrJrQhGcrIZSWtjU	2026-05-20 04:47:50.955837+03	2026-04-20 04:47:50.594543+03
15	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkyNjMyMTh9.Hzk9yf00iVYW3BQUke8vVph1g3kwCthGMB3JKtC5Wxs	2026-05-20 10:46:58.89919+03	2026-04-20 10:46:58.849576+03
16	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkyNjMzMjd9.D1thOQuuua03zveqf8CmvYXrW38B8-_SG3hvtYcGTQQ	2026-05-20 10:48:47.343572+03	2026-04-20 10:48:46.974332+03
23	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkzMDcxNzV9.k86liDDfifhh9e31g5R6W09gVP8Bkx0vywoEjXkdC3s	2026-05-20 22:59:35.911593+03	2026-04-20 22:59:35.909925+03
26	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkzNTMzNjh9.dDYL13IJcQe7x5cMa65xLkb12WPk68G7eg5yD8bnEPI	2026-05-21 11:49:28.381857+03	2026-04-21 11:49:28.380132+03
28	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3NzkzNzk3ODN9.FUT0mxhUPSA_nyAW_H0nX-Gc5042k7KxKjwfvgZv0N8	2026-05-21 19:09:43.551721+03	2026-04-21 19:09:43.550331+03
29	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzk1NTYzODl9.QraF-D1X7FsbHJg_zB0_Ak1XZS-VwbVacc_e4mYTeJY	2026-05-23 20:13:09.872842+03	2026-04-23 20:13:09.315277+03
30	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzk2ODgxMTZ9.eS6d5Ro9oP2ONth7w4BAqUuJEkHcOqg-83x-D9a9GIE	2026-05-25 08:48:36.049472+03	2026-04-25 08:48:35.671375+03
33	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzk5MzIwNTV9.vSeWzLKAgvsgCec86AkvFd36M2Ezz4By4RggAC3YF2k	2026-05-28 04:34:15.780169+03	2026-04-28 04:34:15.707712+03
37	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzk5NTI2Mjd9.egBLpeuaICpg5Hb3LVnL4hejntvUuPBN-vYqsOFNdGw	2026-05-28 10:17:07.393821+03	2026-04-28 10:17:07.346431+03
38	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3Nzk5NjA2NzJ9.IRdIe5E-_pnRmwTAYFnET9IKR3UFyTwT0BrJLytLw2s	2026-05-28 12:31:12.616696+03	2026-04-28 12:31:12.119721+03
40	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODAwNzk5MTJ9.9-fYYJTdSjdThKWrOlGpgoYbZFKXRuvWzNeb7cUtgIs	2026-05-29 21:38:32.22259+03	2026-04-29 21:38:32.157961+03
43	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODAyNDMwNzl9.v0b2KJYzCKw7qh6GGRqaHdaAhp5mYTHLUvLP3QFJy08	2026-05-31 18:57:59.864447+03	2026-05-01 18:57:59.822177+03
44	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODAyNDM2NDF9.9WPCZl-s_tuFh2MhBrKlFN3pGMbDctKT8jCIQNkIw88	2026-05-31 19:07:21.656719+03	2026-05-01 19:07:21.225167+03
45	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODAzMDM0MzF9.tMmmQ54dMOMf0XOvr8XE9adFWF_yZe9TQahsZYHnP6s	2026-06-01 11:43:51.61647+03	2026-05-02 11:43:51.228612+03
46	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA0MjgxNjR9.lb8xPxez9utfiUhrexNACvMFdpSljrZf8mFla-bzCyI	2026-06-02 22:22:44.087081+03	2026-05-03 22:22:43.686049+03
47	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1MDMxOTl9.ipydmo-PfREBlthKPl7bp1iGnC9MJX8Qb-iyAvbf1-4	2026-06-03 19:13:19.900174+03	2026-05-04 19:13:19.822859+03
48	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1MjI2NTd9.lQtiGiZLuD0p0he6RCiQsmi89UaceO8qPHNfySjixYI	2026-06-04 00:37:37.345364+03	2026-05-05 00:37:36.924688+03
49	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1MjMyOTF9.dW6DsKa9ryl8-T8JaM8bCqCAWbbmHRwoVzBcUcF6Xhc	2026-06-04 00:48:11.687046+03	2026-05-05 00:48:11.319104+03
50	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1NDE2NDB9.I0en9jKj2ft_uJUeLLRP_0GY5JvKVpWdq6FYLS9ZWLE	2026-06-04 05:54:00.638105+03	2026-05-05 05:54:00.112794+03
51	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1OTUyNTN9.DsiiF_WhbJI08xOykS754K_eL2MtLVXpuuzS-nRdWU4	2026-06-04 20:47:33.597117+03	2026-05-05 20:47:33.080333+03
52	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1OTcyNTR9.d55jwWBTBlWjBqHvNRCI6G_LXi7cIYaFuHdZ7wPjb0w	2026-06-04 21:20:54.880771+03	2026-05-05 21:20:54.52469+03
53	1	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6InJlZnJlc2giLCJleHAiOjE3ODA1OTgxOTR9.1PcaK0bBayf7Z32GwGFj4b8KKnT913cfOxEshpWHbOE	2026-06-04 21:36:34.22324+03	2026-05-05 21:36:33.857794+03
\.
INSERT INTO web.refresh_tokens (id, user_id, token, expires_at, created_at)
SELECT id, user_id, token, expires_at, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM web.refresh_tokens);
DROP TABLE _stg_load;

SELECT setval('web.refresh_tokens_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM web.refresh_tokens),1), (SELECT count(*) FROM web.refresh_tokens) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'refresh_tokens'
          AND con.conname = 'refresh_tokens_pkey') THEN
        ALTER TABLE ONLY web.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'refresh_tokens'
          AND con.conname = 'refresh_tokens_token_key') THEN
        ALTER TABLE ONLY web.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_key UNIQUE (token);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON web.refresh_tokens USING btree (token);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON web.refresh_tokens USING btree (user_id);
