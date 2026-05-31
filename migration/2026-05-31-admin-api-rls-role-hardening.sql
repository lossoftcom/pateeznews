-- Harden the admin API role used by Cloudflare Hyperdrive.
-- The role connects directly, bypasses no RLS, and keeps access only through
-- explicit grants plus this role-scoped policy.

DO $$
DECLARE
  table_record record;
BEGIN
  FOR table_record IN
    SELECT DISTINCT c.oid, n.nspname, c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN information_schema.role_table_grants g
      ON g.table_schema = n.nspname
     AND g.table_name = c.relname
     AND g.grantee = 'pateez_admin_api'
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
      table_record.nspname,
      table_record.relname
    );

    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = table_record.nspname
        AND tablename = table_record.relname
        AND policyname = 'pateez_admin_api_all'
    ) THEN
      EXECUTE format(
        'CREATE POLICY pateez_admin_api_all ON %I.%I FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true)',
        table_record.nspname,
        table_record.relname
      );
    END IF;
  END LOOP;
END $$;

ALTER ROLE pateez_admin_api LOGIN NOBYPASSRLS;
