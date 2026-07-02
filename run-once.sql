-- ============================================================
-- تشغيل هذا الملف مرة واحدة في SQL Editor في Supabase
-- ============================================================

-- 1. إضافة الأعمدة الجديدة (آمن، IF NOT EXISTS)
ALTER TABLE group_settings ADD COLUMN IF NOT EXISTS slot_fine_from TIME NOT NULL DEFAULT '16:00';
ALTER TABLE group_settings ADD COLUMN IF NOT EXISTS slot_fine_to TIME NOT NULL DEFAULT '20:00';

-- 2. تحديث دالة جلب الإعدادات
CREATE OR REPLACE FUNCTION get_group_settings(
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings JSONB;
BEGIN
  SELECT jsonb_build_object(
    'facility_group_id', gs.facility_group_id,
    'opening_time', gs.opening_time,
    'closing_time_sun', gs.closing_time_sun,
    'closing_time_mon', gs.closing_time_mon,
    'closing_time_tue', gs.closing_time_tue,
    'closing_time_wed', gs.closing_time_wed,
    'closing_time_thu', gs.closing_time_thu,
    'closing_time_fri', gs.closing_time_fri,
    'closing_time_sat', gs.closing_time_sat,
    'deposit_amount', gs.deposit_amount,
    'contract_expiry_hours', gs.contract_expiry_hours,
    'max_booking_hours', gs.max_booking_hours,
    'slot_fine_from', gs.slot_fine_from,
    'slot_fine_to', gs.slot_fine_to
  ) INTO v_settings
  FROM group_settings gs
  WHERE gs.facility_group_id = p_facility_group_id;

  IF v_settings IS NULL THEN
    v_settings := jsonb_build_object(
      'facility_group_id', p_facility_group_id,
      'opening_time', '16:00',
      'closing_time_sun', '22:00',
      'closing_time_mon', '22:00',
      'closing_time_tue', '22:00',
      'closing_time_wed', '22:00',
      'closing_time_thu', '22:00',
      'closing_time_fri', '22:00',
      'closing_time_sat', '22:00',
      'deposit_amount', 5000,
      'contract_expiry_hours', 8,
      'max_booking_hours', 3.0,
      'slot_fine_from', '16:00',
      'slot_fine_to', '20:00'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب الإعدادات',
    'data', v_settings
  );
END;
$$;

-- 3. حذف التواقيع القديمة للدالة (يوجد overload)
DROP FUNCTION IF EXISTS upsert_group_settings(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL(10,2), INT);
DROP FUNCTION IF EXISTS upsert_group_settings(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL(10,2), INT, DECIMAL(3,1));
DROP FUNCTION IF EXISTS upsert_group_settings(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL(10,2), INT, DECIMAL(3,1), TEXT, TEXT);

-- 4. إنشاء الدالة بالتوقيع الجديد
CREATE OR REPLACE FUNCTION upsert_group_settings(
  p_facility_group_id  UUID,
  p_opening_time       TEXT,
  p_closing_time_sun   TEXT,
  p_closing_time_mon   TEXT,
  p_closing_time_tue   TEXT,
  p_closing_time_wed   TEXT,
  p_closing_time_thu   TEXT,
  p_closing_time_fri   TEXT,
  p_closing_time_sat   TEXT,
  p_deposit_amount     DECIMAL(10,2),
  p_contract_expiry_hours INT,
  p_max_booking_hours  DECIMAL(3,1) DEFAULT 3.0,
  p_slot_fine_from     TEXT DEFAULT '16:00',
  p_slot_fine_to       TEXT DEFAULT '20:00'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id   UUID;
  v_admin_role TEXT;
  v_admin_group UUID;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  IF v_admin_role = 'facility_admin' AND p_facility_group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذه المجموعة ليست من صلاحياتك', 'data', null);
  END IF;

  INSERT INTO group_settings (facility_group_id, opening_time, closing_time_sun, closing_time_mon,
    closing_time_tue, closing_time_wed, closing_time_thu, closing_time_fri, closing_time_sat,
    deposit_amount, contract_expiry_hours, max_booking_hours, slot_fine_from, slot_fine_to, updated_by)
  VALUES (p_facility_group_id, p_opening_time::TIME, p_closing_time_sun::TIME, p_closing_time_mon::TIME,
    p_closing_time_tue::TIME, p_closing_time_wed::TIME, p_closing_time_thu::TIME, p_closing_time_fri::TIME,
    p_closing_time_sat::TIME, p_deposit_amount, p_contract_expiry_hours, p_max_booking_hours,
    p_slot_fine_from::TIME, p_slot_fine_to::TIME, v_admin_id)
  ON CONFLICT (facility_group_id) DO UPDATE SET
    opening_time = EXCLUDED.opening_time,
    closing_time_sun = EXCLUDED.closing_time_sun,
    closing_time_mon = EXCLUDED.closing_time_mon,
    closing_time_tue = EXCLUDED.closing_time_tue,
    closing_time_wed = EXCLUDED.closing_time_wed,
    closing_time_thu = EXCLUDED.closing_time_thu,
    closing_time_fri = EXCLUDED.closing_time_fri,
    closing_time_sat = EXCLUDED.closing_time_sat,
    deposit_amount = EXCLUDED.deposit_amount,
    contract_expiry_hours = EXCLUDED.contract_expiry_hours,
    max_booking_hours = EXCLUDED.max_booking_hours,
    slot_fine_from = EXCLUDED.slot_fine_from,
    slot_fine_to = EXCLUDED.slot_fine_to,
    updated_at = now(),
    updated_by = v_admin_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حفظ الإعدادات بنجاح',
    'data', null
  );
END;
$$;

-- 5. صلاحيات التنفيذ (آمنة، GRANT IF EXISTS)
GRANT EXECUTE ON FUNCTION get_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_group_settings TO authenticated;
