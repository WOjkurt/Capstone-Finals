-- Row-level security, part 3: the role the API actually connects as.
--
-- Run this ONCE per database, as the postgres SUPERUSER. It is not part of an EF migration
-- because it creates a login role and needs a password chosen by whoever runs it.
-- dbtc_app cannot run it: creating a role needs CREATEROLE, which dbtc_app deliberately
-- does not have.
--
--   psql -U postgres -d dbtc_sis -f rls_03_runtime_role.sql
--   ALTER ROLE dbtc_api WITH PASSWORD '...';   -- or \password dbtc_api, which does not echo
--
-- Then point ConnectionStrings:DefaultConnection at dbtc_api.
-- To roll back: point it at dbtc_app again. dbtc_app owns the tables, owners are exempt from
-- their own policies, and nothing here uses FORCE ROW LEVEL SECURITY -- so RLS goes inert
-- without dropping a single policy.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbtc_api') THEN
    -- No password here on purpose: it would land in the shared PowerShell history on the
    -- server. Set it separately with \password.
    CREATE ROLE dbtc_api LOGIN;
  END IF;
END $$;

-- dbtc_api must NOT own anything and must NOT be superuser or BYPASSRLS; either would make
-- every policy in rls_02 silently inert.
ALTER ROLE dbtc_api NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

GRANT CONNECT ON DATABASE dbtc_sis TO dbtc_api;
GRANT USAGE ON SCHEMA public, app TO dbtc_api;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dbtc_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dbtc_api;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO dbtc_api;

-- Tables created by future migrations have to be reachable too, otherwise the next migration
-- ships a table the API cannot read and the app breaks after a deploy that looked clean.
ALTER DEFAULT PRIVILEGES FOR ROLE dbtc_app IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dbtc_api;
ALTER DEFAULT PRIVILEGES FOR ROLE dbtc_app IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO dbtc_api;
ALTER DEFAULT PRIVILEGES FOR ROLE dbtc_app IN SCHEMA app
  GRANT EXECUTE ON FUNCTIONS TO dbtc_api;

-- The migrations table is read at startup by EF; it carries no student data.
GRANT SELECT ON "__EFMigrationsHistory" TO dbtc_api;

-- Confirm the role cannot quietly bypass what we just built.
DO $$
DECLARE bad boolean;
BEGIN
  SELECT rolsuper OR rolbypassrls INTO bad FROM pg_roles WHERE rolname = 'dbtc_api';
  IF bad THEN
    RAISE EXCEPTION 'dbtc_api can bypass RLS; policies would be inert';
  END IF;
END $$;
