-- One-time SQL for the discord_bots role (fako-cluster #451).
-- Run ONCE, by Landry, as the CNPG superuser on postgres-cluster-rw, AFTER Flux
-- has created the managed role discord_bots. NOT a Job; not applied by Flux.
-- Idempotent: safe to re-run. Contains no secrets.
--
-- Deliberately NOT included: REVOKE ... ON ALL FUNCTIONS IN SCHEMA public FROM
-- PUBLIC. The app's uuid-ossp and pgcrypto extensions live in public
-- (discord-management migrations/001_schema.sql:9-10; uuid_generate_v4() is a
-- column default), and stripping PUBLIC EXECUTE would break the app's INSERTs.
-- The DB-level REVOKE CONNECT below already keeps other roles out.

-- 1) on database "postgres" (or any)
ALTER DATABASE discord_bots OWNER TO discord_bots;
REVOKE CONNECT, TEMPORARY ON DATABASE discord_bots FROM PUBLIC;
GRANT  CONNECT ON DATABASE discord_bots TO discord_bots;

-- 2) \c discord_bots
ALTER SCHEMA public OWNER TO discord_bots;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;   -- no-op on PG16, kept explicit
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

-- 2a) relations: tables, views, matviews, standalone sequences.
--     serial/identity sequences move with their table, so they are skipped.
--     Extension-owned relations are skipped.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT format('ALTER %s %I.%I OWNER TO discord_bots',
             CASE c.relkind WHEN 'r' THEN 'TABLE' WHEN 'p' THEN 'TABLE'
                            WHEN 'v' THEN 'VIEW'  WHEN 'm' THEN 'MATERIALIZED VIEW'
                            WHEN 'S' THEN 'SEQUENCE' END,
             n.nspname, c.relname) AS stmt
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog','information_schema')
      AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp%'
      AND c.relkind IN ('r','p','v','m','S')
      AND pg_get_userbyid(c.relowner) <> 'discord_bots'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid
                        AND d.deptype = 'e')
      AND NOT (c.relkind = 'S' AND EXISTS (
            SELECT 1 FROM pg_depend d
            WHERE d.objid = c.oid AND d.classid = 'pg_class'::regclass
              AND d.deptype IN ('a','i')))
  LOOP EXECUTE r.stmt; END LOOP;
END $$;

-- 2b) types: ENUM, domain, range and standalone composite types. Array types
--     and table row types follow their parent. Extension-owned types are skipped.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT format('ALTER %s %s OWNER TO discord_bots',
             CASE t.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
             t.oid::regtype) AS stmt
    FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    LEFT JOIN pg_class c ON c.oid = t.typrelid
    WHERE n.nspname NOT IN ('pg_catalog','information_schema')
      AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp%'
      AND (t.typtype IN ('e','d','r') OR (t.typtype = 'c' AND c.relkind = 'c'))
      AND pg_get_userbyid(t.typowner) <> 'discord_bots'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.classid = 'pg_type'::regclass AND d.objid = t.oid
                        AND d.deptype = 'e')
  LOOP EXECUTE r.stmt; END LOOP;
END $$;

-- 2c) functions, procedures, aggregates written by the app (e.g.
--     cleanup_expired_events()). Extension members (uuid-ossp, pgcrypto, ...)
--     are skipped: they stay owned by the extension owner.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT format('ALTER %s %s OWNER TO discord_bots',
             CASE p.prokind WHEN 'p' THEN 'PROCEDURE' WHEN 'a' THEN 'AGGREGATE'
                            ELSE 'FUNCTION' END,
             p.oid::regprocedure) AS stmt
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname NOT IN ('pg_catalog','information_schema')
      AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp%'
      AND pg_get_userbyid(p.proowner) <> 'discord_bots'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid
                        AND d.deptype = 'e')
  LOOP EXECUTE r.stmt; END LOOP;
END $$;

-- 2d) future objects created by discord_bots: no EXECUTE for PUBLIC.
--     (The per-schema table/sequence default-privilege lines from the earlier
--     draft were no-ops and are dropped.)
ALTER DEFAULT PRIVILEGES FOR ROLE discord_bots REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- 3) verify: each query should return 0 rows
SELECT 'rel' AS kind, n.nspname, c.relname AS name, pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r','p','v','m','S') AND pg_get_userbyid(c.relowner) <> 'discord_bots'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_class'::regclass AND d.objid=c.oid AND d.deptype='e')
UNION ALL
SELECT 'type', n.nspname, t.typname, pg_get_userbyid(t.typowner)
FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace LEFT JOIN pg_class c ON c.oid = t.typrelid
WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%'
  AND (t.typtype IN ('e','d','r') OR (t.typtype='c' AND c.relkind='c'))
  AND pg_get_userbyid(t.typowner) <> 'discord_bots'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_type'::regclass AND d.objid=t.oid AND d.deptype='e')
UNION ALL
SELECT 'func', n.nspname, p.oid::regprocedure::text, pg_get_userbyid(p.proowner)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%'
  AND pg_get_userbyid(p.proowner) <> 'discord_bots'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e');

-- 4) sanity: discord_bots can still call extension functions (expect a uuid)
--    SET ROLE discord_bots; SELECT uuid_generate_v4(); RESET ROLE;
