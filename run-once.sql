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

-- 5. دالة حذف الحساب
CREATE OR REPLACE FUNCTION delete_my_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  DELETE FROM wallets WHERE user_id = v_user_id;
  DELETE FROM bookings WHERE user_id = v_user_id;
  DELETE FROM player_ads WHERE creator_id = v_user_id;
  DELETE FROM reports WHERE reporter_id = v_user_id;
  DELETE FROM announcements WHERE sender_id = v_user_id;
  DELETE FROM notifications WHERE user_id = v_user_id;
  DELETE FROM profiles WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم حذف الحساب');
END;
$$;

-- 6. تصحيح get_available_slots: تجاهل الحجوزات المعلقة (pending)
CREATE OR REPLACE FUNCTION get_available_slots(
  p_facility_id UUID,
  p_date        DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booked_slots JSONB;
  v_facility     facilities%ROWTYPE;
  v_day_start    TIMESTAMPTZ;
  v_day_end      TIMESTAMPTZ;
  v_open         TEXT;
  v_close        TEXT;
BEGIN
  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود', 'data', null);
  END IF;

  v_day_start := p_date::TIMESTAMPTZ;
  v_day_end := (p_date + 1)::TIMESTAMPTZ;

  -- Fetch working hours for the group
  SELECT opening_time::TEXT,
    CASE EXTRACT(DOW FROM p_date)
      WHEN 0 THEN closing_time_sun
      WHEN 1 THEN closing_time_mon
      WHEN 2 THEN closing_time_tue
      WHEN 3 THEN closing_time_wed
      WHEN 4 THEN closing_time_thu
      WHEN 5 THEN closing_time_fri
      WHEN 6 THEN closing_time_sat
    END::TEXT INTO v_open, v_close
  FROM group_settings
  WHERE facility_group_id = v_facility.group_id;

  SELECT jsonb_agg(jsonb_build_object(
    'id', bi.id,
    'start_at', bi.start_at,
    'end_at', bi.end_at,
    'status', bi.status,
    'price', bi.price
  ) ORDER BY bi.start_at) INTO v_booked_slots
  FROM booking_instances bi
  WHERE bi.facility_id = p_facility_id
    AND bi.status IN ('confirmed', 'pending_approval')
    AND bi.start_at >= v_day_start
    AND bi.end_at <= v_day_end;

  IF v_booked_slots IS NULL THEN
    v_booked_slots := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object(
      'facility_id', p_facility_id,
      'facility_name', v_facility.name,
      'date', p_date,
      'price_per_hour', v_facility.price_per_hour,
      'opening_time', v_open,
      'closing_time', v_close,
      'booked_slots', v_booked_slots
    )
  );
END;
$$;

-- 7. إعادة إنشاء admin_confirm_booking مع DROP مسبق لحل مشكلة overload
DROP FUNCTION IF EXISTS admin_confirm_booking(UUID);
DROP FUNCTION IF EXISTS admin_confirm_booking(UUID, DECIMAL);

CREATE OR REPLACE FUNCTION admin_confirm_booking(
  p_booking_id UUID,
  p_paid_amount DECIMAL DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    UUID;
  v_admin_role  TEXT;
  v_admin_group UUID;
  v_booking     bookings%ROWTYPE;
  v_facility    facilities%ROWTYPE;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: المشرف فقط يمكنه تأكيد الحجوزات', 'data', null);
  END IF;

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود', 'data', null);
  END IF;

  IF v_booking.status NOT IN ('pending', 'pending_approval') THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز ليس في حالة معلقة', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = v_booking.facility_id;
  IF v_admin_role = 'facility_admin' AND v_facility.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لمجموعتك', 'data', null);
  END IF;

  UPDATE bookings SET
    status = 'confirmed',
    approval_deadline = NULL,
    paid_amount = COALESCE(p_paid_amount, 0),
    payment_status = CASE WHEN COALESCE(p_paid_amount, 0) > 0 THEN 'paid' ELSE 'unpaid' END,
    updated_at = now()
  WHERE id = p_booking_id;

  UPDATE booking_instances SET status = 'confirmed' WHERE booking_id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تأكيد الحجز',
    'data', jsonb_build_object(
      'booking_id', p_booking_id,
      'status', 'confirmed',
      'paid_amount', COALESCE(p_paid_amount, 0),
      'payment_status', CASE WHEN COALESCE(p_paid_amount, 0) > 0 THEN 'paid' ELSE 'unpaid' END
    )
  );
END;
$$;

-- 8. صلاحيات التنفيذ
GRANT EXECUTE ON FUNCTION get_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION delete_my_account TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_slots TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_booking(UUID, DECIMAL) TO authenticated;
