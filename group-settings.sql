-- ============================================================
-- Group Settings table
-- Run this separately (not the full schema)
-- ============================================================

CREATE TABLE IF NOT EXISTS group_settings (
  facility_group_id  UUID PRIMARY KEY REFERENCES facility_groups(id) ON DELETE CASCADE,
  opening_time       TIME NOT NULL DEFAULT '16:00',
  closing_time_sun   TIME NOT NULL DEFAULT '22:00',
  closing_time_mon   TIME NOT NULL DEFAULT '22:00',
  closing_time_tue   TIME NOT NULL DEFAULT '22:00',
  closing_time_wed   TIME NOT NULL DEFAULT '22:00',
  closing_time_thu   TIME NOT NULL DEFAULT '22:00',
  closing_time_fri   TIME NOT NULL DEFAULT '22:00',
  closing_time_sat   TIME NOT NULL DEFAULT '22:00',
  deposit_amount     DECIMAL(10,2) NOT NULL DEFAULT 5000,
  contract_expiry_hours INT NOT NULL DEFAULT 8,
  max_booking_hours  DECIMAL(3,1) NOT NULL DEFAULT 3.0,
  updated_at         TIMESTAMPTZ DEFAULT now(),
  updated_by         UUID REFERENCES profiles(id) ON DELETE SET NULL
);

ALTER TABLE group_settings ENABLE ROW LEVEL SECURITY;

-- Add column if upgrading from existing schema (safe to run on fresh install too)
ALTER TABLE group_settings ADD COLUMN IF NOT EXISTS max_booking_hours DECIMAL(3,1) NOT NULL DEFAULT 3.0;
ALTER TABLE group_settings ADD COLUMN IF NOT EXISTS slot_fine_from TIME NOT NULL DEFAULT '16:00';
ALTER TABLE group_settings ADD COLUMN IF NOT EXISTS slot_fine_to TIME NOT NULL DEFAULT '20:00';

DO $policies$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'group_settings_select_admin' AND tablename = 'group_settings') THEN
    CREATE POLICY "group_settings_select_admin"
      ON group_settings FOR SELECT
      USING (
        user_role() IN ('facility_admin', 'facility_viewer', 'super_admin')
        AND (
          user_role() = 'super_admin'
          OR facility_group_id = user_facility_group_id()
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'group_settings_insert_admin' AND tablename = 'group_settings') THEN
    CREATE POLICY "group_settings_insert_admin"
      ON group_settings FOR INSERT
      WITH CHECK (
        user_role() IN ('facility_admin', 'super_admin')
        AND (
          user_role() = 'super_admin'
          OR facility_group_id = user_facility_group_id()
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'group_settings_update_admin' AND tablename = 'group_settings') THEN
    CREATE POLICY "group_settings_update_admin"
      ON group_settings FOR UPDATE
      USING (
        user_role() IN ('facility_admin', 'super_admin')
        AND (
          user_role() = 'super_admin'
          OR facility_group_id = user_facility_group_id()
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'group_settings_delete_admin' AND tablename = 'group_settings') THEN
    CREATE POLICY "group_settings_delete_admin"
      ON group_settings FOR DELETE
      USING (
        user_role() IN ('facility_admin', 'super_admin')
        AND (
          user_role() = 'super_admin'
          OR facility_group_id = user_facility_group_id()
        )
      );
  END IF;
END;
$policies$;
