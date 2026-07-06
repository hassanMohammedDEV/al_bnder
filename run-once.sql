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
CREATE OR REPLACE FUNCTION delete_my_account(p_dummy TEXT DEFAULT '')
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
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
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'announcement_reads') THEN
    DELETE FROM announcement_reads WHERE user_id = v_user_id;
  END IF;
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'reports') THEN
    DELETE FROM reports WHERE reporter_id = v_user_id;
  END IF;
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'announcements') THEN
    DELETE FROM announcements WHERE sender_id = v_user_id;
  END IF;
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
    DELETE FROM notifications WHERE user_id = v_user_id;
  END IF;
  DELETE FROM profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

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

-- 8. إصلاح generate_recurring_dates: تهيئة المصفوفة فارغة + قيمة افتراضية للـ frequency
DROP FUNCTION IF EXISTS generate_recurring_dates(TIMESTAMPTZ, JSONB);

CREATE OR REPLACE FUNCTION generate_recurring_dates(
  p_start_at        TIMESTAMPTZ,
  p_recurring_rule  JSONB
)
RETURNS TIMESTAMPTZ[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_dates        TIMESTAMPTZ[] := ARRAY[]::TIMESTAMPTZ[];
  v_frequency    TEXT;
  v_days_of_week INT[];
  v_end_date     DATE;
  v_count        INT;
  v_current      DATE;
  v_day_of_week  INT;
  v_start_time   TIME;
BEGIN
  v_frequency := COALESCE(p_recurring_rule->>'frequency', 'weekly');
  v_days_of_week := ARRAY(SELECT jsonb_array_elements_text(p_recurring_rule->'days_of_week')::INT);
  v_end_date := (p_recurring_rule->>'end_date')::DATE;
  v_count := (p_recurring_rule->>'count')::INT;
  v_start_time := p_start_at::TIME;
  v_current := p_start_at::DATE;

  IF v_frequency = 'weekly' THEN
    WHILE v_current <= COALESCE(v_end_date, v_current + INTERVAL '1 year')
    LOOP
      v_day_of_week := EXTRACT(DOW FROM v_current)::INT;
      IF v_day_of_week = ANY(v_days_of_week) THEN
        v_dates := array_append(v_dates, v_current + v_start_time);
      END IF;
      v_current := v_current + INTERVAL '1 day';
      IF v_count IS NOT NULL AND array_length(v_dates, 1) >= v_count THEN
        EXIT;
      END IF;
    END LOOP;
  END IF;

  RETURN v_dates;
END;
$$;

-- 9. دالة إلغاء موعد واحد من حجز متسلسل
CREATE OR REPLACE FUNCTION cancel_booking_instance(
  p_booking_id UUID,
  p_instance_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID;
  v_user_role      TEXT;
  v_user_group     UUID;
  v_instance       booking_instances%ROWTYPE;
  v_booking        bookings%ROWTYPE;
  v_facility       facilities%ROWTYPE;
  v_remaining      INT;
  v_new_total      DECIMAL(10,2);
BEGIN
  v_user_id := auth.uid();
  SELECT role, facility_group_id INTO v_user_role, v_user_group
  FROM profiles WHERE id = v_user_id;

  SELECT * INTO v_instance FROM booking_instances WHERE id = p_instance_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الموعد غير موجود');
  END IF;

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود');
  END IF;

  IF v_user_role != 'facility_admin' THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  SELECT group_id INTO v_facility FROM facilities WHERE id = v_booking.facility_id;
  IF v_facility.group_id != v_user_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لمجموعتك');
  END IF;

  IF v_instance.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'message', 'الموعد ملغي مسبقاً');
  END IF;

  IF v_instance.start_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن إلغاء موعد بعد بدء الوقت');
  END IF;

  UPDATE booking_instances SET status = 'cancelled'
  WHERE id = p_instance_id;

  SELECT COALESCE(SUM(price), 0) INTO v_new_total
  FROM booking_instances
  WHERE booking_id = p_booking_id AND status NOT IN ('cancelled', 'completed');

  UPDATE bookings SET
    total_price = v_new_total,
    updated_at = now()
  WHERE id = p_booking_id;

  SELECT COUNT(*) INTO v_remaining
  FROM booking_instances
  WHERE booking_id = p_booking_id AND status NOT IN ('cancelled', 'completed');

  IF v_remaining = 0 THEN
    UPDATE bookings SET status = 'cancelled', updated_at = now()
    WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إلغاء الموعد بنجاح',
    'data', jsonb_build_object(
      'booking_id', p_booking_id,
      'instance_id', p_instance_id,
      'new_total', v_new_total,
      'remaining', v_remaining
    )
  );
END;
$$;

-- 10. صلاحيات التنفيذ
GRANT EXECUTE ON FUNCTION get_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION delete_my_account TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_slots TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_booking(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_booking_instance TO authenticated;

-- 11. أعمدة الإعلانات الرسمية
ALTER TABLE player_ads ADD COLUMN IF NOT EXISTS is_official BOOLEAN DEFAULT false;
ALTER TABLE player_ads ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- 12. تحديث get_player_ads لترتيب الإعلانات الرسمية في الأعلى
CREATE OR REPLACE FUNCTION get_player_ads(
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ads JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', pa.id,
    'facility_group_id', pa.facility_group_id,
    'creator_id', pa.creator_id,
    'creator_name', COALESCE(u.full_name, pa.creator_name, ''),
    'creator_phone', COALESCE(u.phone, ''),
    'type', pa.type,
    'days', pa.days,
    'start_time', pa.start_time,
    'end_time', pa.end_time,
    'facility_id', pa.facility_id,
    'facility_name', pa.facility_name,
    'date', pa.date,
    'players_needed', pa.players_needed,
    'position', pa.position,
    'notes', pa.notes,
    'status', pa.status,
    'created_at', pa.created_at,
    'is_official', pa.is_official,
    'pinned_at', pa.pinned_at
  ) ORDER BY pa.pinned_at DESC NULLS LAST, pa.created_at DESC) INTO v_ads
  FROM player_ads pa
  LEFT JOIN profiles u ON u.id = pa.creator_id
  WHERE pa.facility_group_id = p_facility_group_id
    AND pa.status = 'active'
    AND (pa.date IS NULL OR pa.date::DATE >= CURRENT_DATE);

  IF v_ads IS NULL THEN
    v_ads := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'success',
    'data', v_ads
  );
END;
$$;

-- 13. دالة إنشاء إعلان رسمي (للمدير فقط)
CREATE OR REPLACE FUNCTION create_official_player_ad(
  p_facility_group_id UUID,
  p_type              TEXT,
  p_days              TEXT[] DEFAULT '{}',
  p_start_time        TEXT DEFAULT NULL,
  p_end_time          TEXT DEFAULT NULL,
  p_facility_id       UUID DEFAULT NULL,
  p_facility_name     TEXT DEFAULT NULL,
  p_date              TEXT DEFAULT NULL,
  p_players_needed    INT DEFAULT NULL,
  p_position          TEXT DEFAULT NULL,
  p_notes             TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_phone     TEXT;
  v_ad_id     UUID;
BEGIN
  v_user_id := auth.uid();
  SELECT role, phone INTO v_user_role, v_phone
  FROM profiles WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  INSERT INTO player_ads (
    facility_group_id, creator_id, creator_name, creator_phone,
    type, days, start_time, end_time,
    facility_id, facility_name, date,
    players_needed, position, notes,
    is_official, pinned_at
  ) VALUES (
    p_facility_group_id, v_user_id, 'إدارة الملعب', COALESCE(v_phone, ''),
    p_type, p_days, p_start_time, p_end_time,
    p_facility_id, p_facility_name, p_date,
    p_players_needed, p_position, p_notes,
    true, now()
  )
  RETURNING id INTO v_ad_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم نشر الإعلان الرسمي',
    'data', jsonb_build_object('id', v_ad_id)
  );
END;
$$;

-- 14. صلاحيات إضافية
GRANT EXECUTE ON FUNCTION create_official_player_ad TO authenticated;

-- 15. إشعار تلغرام للحجوزات (رسالة واحدة لكل حجز)
DROP FUNCTION IF EXISTS notify_telegram_new_booking() CASCADE;
CREATE OR REPLACE FUNCTION public.notify_telegram_new_booking(p_booking_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_token   TEXT := '8746929485:AAFHOmVFVDBrmmHE8WUcJ7xffzRZGz7NLSo';
  v_chat_id TEXT := '8756453222';
  v_body    JSONB;
  v_text    TEXT;
  v_booking bookings%ROWTYPE;
  v_facility_name TEXT;
  v_group_name TEXT;
  v_instances_text TEXT;
  v_rec RECORD;
  v_count INT;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT f.name, fg.name INTO v_facility_name, v_group_name
  FROM facilities f
  JOIN facility_groups fg ON fg.id = f.group_id
  WHERE f.id = v_booking.facility_id;

  v_instances_text := '';
  SELECT COUNT(*) INTO v_count FROM booking_instances WHERE booking_id = p_booking_id AND status != 'cancelled';

  FOR v_rec IN
    SELECT start_at, end_at, price
    FROM booking_instances
    WHERE booking_id = p_booking_id AND status != 'cancelled'
    ORDER BY start_at
  LOOP
    v_instances_text := v_instances_text ||
      '📅 ' || to_char(v_rec.start_at AT TIME ZONE 'Asia/Aden', 'YYYY-MM-dd') || ' ' ||
      to_char(v_rec.start_at AT TIME ZONE 'Asia/Aden', 'HH12:MI') || ' ' ||
      CASE WHEN EXTRACT(HOUR FROM v_rec.start_at AT TIME ZONE 'Asia/Aden') < 12 THEN 'ص' ELSE 'م' END || ' → ' ||
      to_char(v_rec.end_at AT TIME ZONE 'Asia/Aden', 'HH12:MI') || ' ' ||
      CASE WHEN EXTRACT(HOUR FROM v_rec.end_at AT TIME ZONE 'Asia/Aden') < 12 THEN 'ص' ELSE 'م' END ||
      ' | ' || v_rec.price::text || ' ر.ي' || E'\n';
  END LOOP;

  v_text :=
    '📌 حجز جديد' || E'\n' ||
    '━━━━━━━━━━━━' || E'\n' ||
    '👤 ' || COALESCE(
      (SELECT full_name FROM profiles WHERE id = v_booking.user_id),
      v_booking.guest_name, 'زائر'
    ) || E'\n' ||
    '📞 ' || COALESCE(
      (SELECT phone FROM profiles WHERE id = v_booking.user_id),
      v_booking.guest_phone, '–'
    ) || E'\n' ||
    '🏟️ ' || v_facility_name || ' - ' || v_group_name || E'\n' ||
    E'\n' ||
    v_instances_text || E'\n' ||
    '💰 الإجمالي: ' || v_booking.total_price::text || ' ر.ي' || E'\n' ||
    '💳 مدفوع: ' || COALESCE(v_booking.paid_amount, 0)::text || ' ر.ي' || E'\n' ||
    '📋 ' || CASE v_booking.is_admin_booking WHEN true THEN 'دفع خارج التطبيق' ELSE v_booking.payment_status END || E'\n' ||
    '📋 ' || CASE v_booking.is_recurring WHEN true THEN 'متكرر (' || v_count || ' مواعيد)' ELSE 'مرة واحدة' END;

  v_body := jsonb_build_object('chat_id', v_chat_id, 'text', v_text);

  BEGIN
    PERFORM net.http_post(
      url := 'https://api.telegram.org/bot' || v_token || '/sendMessage',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := v_body
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

DROP TRIGGER IF EXISTS trg_booking_instance_telegram ON booking_instances;
GRANT EXECUTE ON FUNCTION notify_telegram_new_booking TO authenticated;

-- 16. تحديث create_booking (إضافة إشعار تلغرام)
DROP FUNCTION IF EXISTS create_booking(UUID, TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN, JSONB);
CREATE OR REPLACE FUNCTION create_booking(
  p_facility_id    UUID,
  p_start_at       TIMESTAMPTZ,
  p_end_at         TIMESTAMPTZ,
  p_is_recurring   BOOLEAN DEFAULT false,
  p_recurring_rule JSONB   DEFAULT null,
  p_payment_type   TEXT    DEFAULT 'auto'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID;
  v_facility       facilities%ROWTYPE;
  v_hours          DECIMAL(10,2);
  v_total_price    DECIMAL(10,2);
  v_booking_id     UUID;
  v_group_id       UUID;
  v_wallet         wallets%ROWTYPE;
  v_instances      TIMESTAMPTZ[];
  v_instance       TIMESTAMPTZ;
  v_instance_end   TIMESTAMPTZ;
  v_confirmed      BOOLEAN;
  v_lock_key       BIGINT;
  v_balance_after  DECIMAL(10,2);
  v_instance_count INT;
  v_deposit_amount DECIMAL(10,2);
  v_paid_amount    DECIMAL(10,2);
  v_payment_status TEXT;
  v_status         TEXT;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى تسجيل الدخول أولاً', 'data', null);
  END IF;

  IF p_payment_type NOT IN ('auto', 'full', 'deposit') THEN
    RETURN jsonb_build_object('success', false, 'message', 'نوع الدفع غير صالح', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود أو غير نشط', 'data', null);
  END IF;

  v_group_id := v_facility.group_id;

  SELECT COALESCE(deposit_amount, 5000) INTO v_deposit_amount
  FROM group_settings WHERE facility_group_id = v_group_id;

  IF p_end_at <= p_start_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية يجب أن يكون بعد وقت البداية', 'data', null);
  END IF;

  IF NOT is_within_working_hours(v_group_id, p_start_at, p_end_at) THEN
    RETURN jsonb_build_object('success', false, 'message', 'الوقت المحدد خارج أوقات العمل', 'data', null);
  END IF;

  v_lock_key := hashtext(p_facility_id::TEXT || p_start_at::TEXT);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF EXISTS (
    SELECT 1 FROM booking_instances bi
    WHERE bi.facility_id = p_facility_id
      AND bi.status IN ('confirmed', 'pending', 'pending_approval')
      AND bi.start_at < p_end_at
      AND bi.end_at > p_start_at
      FOR UPDATE
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'هذا الوقت محجوز مسبقاً',
      'data', null
    );
  END IF;

  -- Calculate total price BEFORE any insert
  IF p_is_recurring AND p_recurring_rule IS NOT NULL THEN
    v_instances := generate_recurring_dates(p_start_at, p_recurring_rule);
    v_total_price := 0;
    FOREACH v_instance IN ARRAY v_instances
    LOOP
      v_instance_end := v_instance + (p_end_at - p_start_at);
      IF NOT is_within_working_hours(v_group_id, v_instance, v_instance_end) THEN
        RETURN jsonb_build_object('success', false, 'message',
          'أحد المواعيد المتكررة خارج أوقات العمل: ' || v_instance::TEXT, 'data', null);
      END IF;
      v_hours := EXTRACT(EPOCH FROM (v_instance_end - v_instance)) / 3600;
      v_total_price := v_total_price + (v_hours * v_facility.price_per_hour);
    END LOOP;
    v_instance_count := array_length(v_instances, 1);
  ELSE
    v_hours := EXTRACT(EPOCH FROM (p_end_at - p_start_at)) / 3600;
    v_total_price := v_hours * v_facility.price_per_hour;
    v_instance_count := 1;
  END IF;

  -- Validate wallet BEFORE insert (prevents leaked pending bookings)
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_user_id AND facility_group_id = v_group_id
  FOR UPDATE;

  v_paid_amount := 0;
  v_balance_after := COALESCE(v_wallet.balance, 0);
  v_confirmed := false;

  IF p_payment_type = 'full' THEN
    IF v_wallet.balance IS NULL OR v_wallet.balance < v_total_price THEN
      RETURN jsonb_build_object('success', false, 'message', 'الرصيد غير كافٍ للدفع الكامل', 'data', null);
    END IF;
    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_amount := v_total_price;
    v_confirmed := true;
  ELSIF p_payment_type = 'deposit' THEN
    IF v_wallet.balance IS NULL OR v_wallet.balance < v_deposit_amount THEN
      RETURN jsonb_build_object('success', false, 'message', 'الرصيد غير كافٍ لدفع العربون', 'data', null);
    END IF;
    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_amount := v_deposit_amount;
    v_confirmed := true;
  ELSE
    -- 'auto'
    IF v_wallet.balance IS NOT NULL AND v_wallet.balance >= v_total_price THEN
      v_status := 'confirmed';
      v_payment_status := 'paid';
      v_paid_amount := v_total_price;
      v_confirmed := true;
    ELSIF v_wallet.balance IS NOT NULL AND v_wallet.balance >= v_deposit_amount THEN
      v_status := 'confirmed';
      v_payment_status := 'paid';
      v_paid_amount := v_deposit_amount;
      v_confirmed := true;
    ELSE
      v_status := 'pending';
      v_payment_status := 'unpaid';
      v_confirmed := false;
    END IF;
  END IF;

  -- Now INSERT booking with correct status (no leaks)
  IF p_is_recurring AND p_recurring_rule IS NOT NULL THEN
    INSERT INTO bookings (user_id, facility_id, total_price, status, payment_status,
                          is_recurring, recurring_rule)
    VALUES (v_user_id, p_facility_id, v_total_price, v_status, v_payment_status,
            true, p_recurring_rule)
    RETURNING id INTO v_booking_id;

    FOREACH v_instance IN ARRAY v_instances
    LOOP
      v_instance_end := v_instance + (p_end_at - p_start_at);
      INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
      VALUES (v_booking_id, p_facility_id, v_instance, v_instance_end,
              v_hours * v_facility.price_per_hour, v_status);
    END LOOP;
  ELSE
    INSERT INTO bookings (user_id, facility_id, total_price, status, payment_status, paid_amount)
    VALUES (v_user_id, p_facility_id, v_total_price, v_status, v_payment_status, v_paid_amount)
    RETURNING id INTO v_booking_id;

    INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
    VALUES (v_booking_id, p_facility_id, p_start_at, p_end_at, v_total_price, v_status);
  END IF;

  -- Deduct wallet if confirmed
  IF v_confirmed AND v_paid_amount > 0 THEN
    UPDATE wallets SET balance = balance - v_paid_amount WHERE id = v_wallet.id
    RETURNING balance INTO v_balance_after;

    INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
    VALUES (v_wallet.id, v_paid_amount, 'withdrawal', 'booking', v_booking_id,
            CASE WHEN p_payment_type = 'full' THEN 'خصم حجز (دفع كامل): ' || v_facility.name
                 WHEN p_payment_type = 'deposit' THEN 'خصم حجز (عربون): ' || v_facility.name
                 ELSE 'خصم حجز: ' || v_facility.name END);
  END IF;

  PERFORM notify_telegram_new_booking(v_booking_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN v_confirmed THEN 'تم تأكيد الحجز' ELSE 'الحجز معلق بانتظار تأكيد الإدارة' END,
    'data', jsonb_build_object(
      'booking_id', v_booking_id,
      'facility_name', v_facility.name,
      'total_price', v_total_price,
      'paid_amount', v_paid_amount,
      'deposit_amount', v_deposit_amount,
      'status', v_status,
      'payment_status', v_payment_status,
      'is_recurring', p_is_recurring,
      'instance_count', v_instance_count,
      'balance_after', v_balance_after
    )
  );
END;
$$;

-- -------------------------------------------------------
-- 17. تحديث admin_create_booking (إضافة إشعار تلغرام)
-- حذف جميع الصيغ القديمة للدالة لتجنب تعارض الصيغ
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_create_booking' AND pronamespace = 'public'::regnamespace) THEN
    EXECUTE (
      SELECT string_agg(format('DROP FUNCTION IF EXISTS %s(%s) CASCADE', p.oid::regproc, pg_get_function_identity_arguments(p.oid)), '; ')
      FROM pg_proc p
      WHERE p.proname = 'admin_create_booking' AND p.pronamespace = 'public'::regnamespace
    );
  END IF;
END $$;
CREATE OR REPLACE FUNCTION admin_create_booking(
  p_facility_id      UUID,
  p_start_at         TIMESTAMPTZ,
  p_end_at           TIMESTAMPTZ,
  p_target_user_id   UUID    DEFAULT NULL,
  p_target_name      TEXT    DEFAULT NULL,
  p_target_phone     TEXT    DEFAULT NULL,
  p_is_recurring     BOOLEAN DEFAULT false,
  p_recurring_rule   JSONB   DEFAULT null,
  p_auto_confirm     BOOLEAN DEFAULT true,
  p_payment_type     TEXT    DEFAULT 'full'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id       UUID;
  v_admin_role     TEXT;
  v_admin_group    UUID;
  v_facility       facilities%ROWTYPE;
  v_hours          DECIMAL(10,2);
  v_total_price    DECIMAL(10,2);
  v_booking_id     UUID;
  v_group_id       UUID;
  v_wallet         wallets%ROWTYPE;
  v_instances      TIMESTAMPTZ[];
  v_instance       TIMESTAMPTZ;
  v_instance_end   TIMESTAMPTZ;
  v_confirmed      BOOLEAN;
  v_lock_key       BIGINT;
  v_balance_after  DECIMAL(10,2);
  v_instance_count INT;
  v_is_guest       BOOLEAN;
  v_deadline       TIMESTAMPTZ;
  v_expiry_hours   INT;
  v_target_status  TEXT;
  v_deposit_amount DECIMAL(10,2);
  v_paid_amount    DECIMAL(10,2);
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'facility_viewer', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  IF p_payment_type NOT IN ('full', 'deposit') THEN
    RETURN jsonb_build_object('success', false, 'message', 'نوع الدفع غير صالح', 'data', null);
  END IF;

  v_is_guest := p_target_user_id IS NULL;

  IF v_is_guest AND p_target_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى إدخال اسم المستخدم', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود أو غير نشط', 'data', null);
  END IF;

  v_group_id := v_facility.group_id;

  -- Fetch deposit amount
  SELECT COALESCE(deposit_amount, 5000) INTO v_deposit_amount
  FROM group_settings WHERE facility_group_id = v_group_id;

  IF v_admin_role != 'super_admin' AND v_group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الملعب ليس لمجموعتك', 'data', null);
  END IF;

  IF p_end_at <= p_start_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية يجب أن يكون بعد وقت البداية', 'data', null);
  END IF;

  -- Check working hours
  IF NOT is_within_working_hours(v_group_id, p_start_at, p_end_at) THEN
    RETURN jsonb_build_object('success', false, 'message', 'الوقت المحدد خارج أوقات العمل', 'data', null);
  END IF;

  v_lock_key := hashtext(p_facility_id::TEXT || p_start_at::TEXT);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF EXISTS (
    SELECT 1 FROM booking_instances bi
    WHERE bi.facility_id = p_facility_id
      AND bi.status IN ('confirmed', 'pending', 'pending_approval')
      AND bi.start_at < p_end_at
      AND bi.end_at > p_start_at
      FOR UPDATE
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'هذا الوقت محجوز مسبقاً', 'data', null);
  END IF;

  -- Determine target status
  IF p_auto_confirm THEN
    v_target_status := 'confirmed';
  ELSE
    SELECT COALESCE(contract_expiry_hours, 8) INTO v_expiry_hours
    FROM group_settings WHERE facility_group_id = v_group_id;
    v_deadline := now() + (v_expiry_hours || ' hours')::INTERVAL;
    v_target_status := 'pending_approval';
  END IF;

  IF p_is_recurring AND p_recurring_rule IS NOT NULL THEN
    INSERT INTO bookings (user_id, guest_name, guest_phone, facility_id, total_price, status, payment_status,
                          is_recurring, recurring_rule, approval_deadline, is_admin_booking)
    VALUES (p_target_user_id, CASE WHEN v_is_guest THEN p_target_name ELSE NULL END,
            CASE WHEN v_is_guest THEN p_target_phone ELSE NULL END,
            p_facility_id, 0, v_target_status, CASE WHEN p_auto_confirm THEN 'paid' ELSE 'unpaid' END,
            true, p_recurring_rule, v_deadline, true)
    RETURNING id INTO v_booking_id;

    v_instances := generate_recurring_dates(p_start_at, p_recurring_rule);

    FOREACH v_instance IN ARRAY v_instances
    LOOP
      v_instance_end := v_instance + (p_end_at - p_start_at);
      IF NOT is_within_working_hours(v_group_id, v_instance, v_instance_end) THEN
        RETURN jsonb_build_object('success', false, 'message',
          'أحد المواعيد المتكررة خارج أوقات العمل: ' || v_instance::TEXT, 'data', null);
      END IF;
      v_hours := EXTRACT(EPOCH FROM (v_instance_end - v_instance)) / 3600;
      INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
      VALUES (v_booking_id, p_facility_id, v_instance, v_instance_end,
              v_hours * v_facility.price_per_hour, v_target_status);
    END LOOP;

    SELECT COALESCE(SUM(price), 0) INTO v_total_price
    FROM booking_instances WHERE booking_id = v_booking_id;

    UPDATE bookings SET total_price = v_total_price WHERE id = v_booking_id;

    SELECT COUNT(*) INTO v_instance_count
    FROM booking_instances WHERE booking_id = v_booking_id;
  ELSE
    v_hours := EXTRACT(EPOCH FROM (p_end_at - p_start_at)) / 3600;
    v_total_price := v_hours * v_facility.price_per_hour;

    INSERT INTO bookings (user_id, guest_name, guest_phone, facility_id, total_price, status, payment_status, approval_deadline, is_admin_booking)
    VALUES (p_target_user_id, CASE WHEN v_is_guest THEN p_target_name ELSE NULL END,
            CASE WHEN v_is_guest THEN p_target_phone ELSE NULL END,
            p_facility_id, v_total_price, v_target_status,
            CASE WHEN p_auto_confirm THEN 'paid' ELSE 'unpaid' END,
            v_deadline, true)
    RETURNING id INTO v_booking_id;

    INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
    VALUES (v_booking_id, p_facility_id, p_start_at, p_end_at, v_total_price, v_target_status);

    v_instance_count := 1;
  END IF;

  -- Auto-confirm: deduct from wallet if registered
  IF p_auto_confirm AND NOT v_is_guest THEN
    SELECT * INTO v_wallet
    FROM wallets
    WHERE user_id = p_target_user_id AND facility_group_id = v_group_id
    FOR UPDATE;

    IF FOUND THEN
      IF p_payment_type = 'full' THEN
        IF v_wallet.balance >= v_total_price THEN
          v_paid_amount := v_total_price;
          UPDATE wallets SET balance = balance - v_paid_amount WHERE id = v_wallet.id
          RETURNING balance INTO v_balance_after;
          INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
          VALUES (v_wallet.id, v_paid_amount, 'withdrawal', 'booking', v_booking_id,
                  'خصم حجز (بواسطة المشرف): ' || v_facility.name);
        ELSE
          v_paid_amount := 0;
          v_balance_after := v_wallet.balance;
        END IF;
      ELSE
        -- 'deposit'
        IF v_wallet.balance >= v_deposit_amount THEN
          v_paid_amount := v_deposit_amount;
          UPDATE wallets SET balance = balance - v_paid_amount WHERE id = v_wallet.id
          RETURNING balance INTO v_balance_after;
          INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
          VALUES (v_wallet.id, v_paid_amount, 'withdrawal', 'booking', v_booking_id,
                  'خصم حجز (عربون، بواسطة المشرف): ' || v_facility.name);
        ELSE
          v_paid_amount := 0;
          v_balance_after := v_wallet.balance;
        END IF;
      END IF;

      UPDATE bookings SET paid_amount = v_paid_amount WHERE id = v_booking_id;
    ELSE
      v_balance_after := 0;
    END IF;
  ELSE
    v_balance_after := 0;
  END IF;

  v_confirmed := p_auto_confirm;

  PERFORM notify_telegram_new_booking(v_booking_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN v_confirmed THEN 'تم تأكيد الحجز'
                ELSE 'تم إنشاء حجز شبه مؤكد. ينتهي خلال ' || COALESCE(v_deadline::TEXT, '') END,
    'data', jsonb_build_object(
      'booking_id', v_booking_id,
      'target_user_id', p_target_user_id,
      'target_name', CASE WHEN v_is_guest THEN p_target_name ELSE NULL END,
      'facility_name', v_facility.name,
      'total_price', v_total_price,
      'paid_amount', v_paid_amount,
      'deposit_amount', v_deposit_amount,
      'status', v_target_status,
      'payment_status', CASE WHEN p_auto_confirm THEN 'paid' ELSE 'unpaid' END,
      'is_recurring', p_is_recurring,
      'instance_count', v_instance_count,
      'balance_after', v_balance_after,
      'approval_deadline', v_deadline
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_booking TO authenticated;

-- 18. استعادة كلمة السر عبر SMS
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION forgot_password(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_id UUID;
  v_new_password TEXT;
  v_sms_token TEXT;
BEGIN
  SELECT id INTO v_user_id FROM profiles WHERE phone = p_phone;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'رقم الجوال غير مسجل');
  END IF;

  v_new_password := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 8));

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(v_new_password, extensions.gen_salt('bf'))
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المستخدم غير موجود في نظام التوثيق');
  END IF;

  v_sms_token := 'f553Lv0dTZGY3qwFRAdUan:APA91bHdlPb8gXlxRvEXY-pQWOhfnsheKK7qdMmD1Nnb6LV9Yhl8VbixYserGbOgRBn3AA9rnooVfP-BNi4TEVD8ssAWiQHQTyHX4J4iN7fpJT7UKucCxQA';

  PERFORM net.http_post(
    url := 'https://www.traccar.org/sms/',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', v_sms_token
    ),
    body := jsonb_build_object(
      'to', p_phone,
      'message', 'كلمة المرور الجديدة: ' || v_new_password
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم إرسال كلمة السر الجديدة');
END;
$$;

GRANT EXECUTE ON FUNCTION forgot_password TO anon, authenticated;

-- 19. تحديث الملف الشخصي (الاسم)
CREATE OR REPLACE FUNCTION update_my_profile(p_full_name TEXT)
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

  UPDATE profiles SET full_name = p_full_name, updated_at = now()
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم تحديث الملف الشخصي');
END;
$$;

GRANT EXECUTE ON FUNCTION update_my_profile TO authenticated;

-- 20. تغيير كلمة السر (للمستخدم المسجل دخوله)
CREATE OR REPLACE FUNCTION change_my_password(p_new_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf'))
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم تغيير كلمة السر');
END;
$$;

GRANT EXECUTE ON FUNCTION change_my_password TO authenticated;

-- 21. إعادة تعيين كلمة سر مستخدم (للمدير فقط) وإرجاعها
CREATE OR REPLACE FUNCTION admin_reset_user_password(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_admin_id UUID;
  v_admin_role TEXT;
  v_user_id UUID;
  v_new_password TEXT;
BEGIN
  v_admin_id := auth.uid();
  SELECT role INTO v_admin_role FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  SELECT id INTO v_user_id FROM profiles WHERE phone = p_phone;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'رقم الجوال غير مسجل');
  END IF;

  v_new_password := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 8));

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(v_new_password, extensions.gen_salt('bf'))
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إعادة تعيين كلمة السر',
    'data', jsonb_build_object('new_password', v_new_password)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_reset_user_password TO authenticated;

-- ============================================================
-- 18. OTP Verification
-- ============================================================

-- جدول رموز التحقق
CREATE TABLE IF NOT EXISTS otp_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- إضافة عمود phone_verified إلى profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;

-- تعيين جميع المستخدمين الحاليين كمتحقق (للهجرة من قبل الميزة)
UPDATE profiles SET phone_verified = true WHERE phone_verified IS NULL OR phone_verified = false;

-- إنشاء رمز تحقق وإرساله عبر SMS
CREATE OR REPLACE FUNCTION generate_otp(
  p_phone   TEXT,
  p_purpose TEXT DEFAULT 'registration'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_code  TEXT;
  v_token TEXT := 'f553Lv0dTZGY3qwFRAdUan:APA91bHdlPb8gXlxRvEXY-pQWOhfnsheKK7qdMmD1Nnb6LV9Yhl8VbixYserGbOgRBn3AA9rnooVfP-BNi4TEVD8ssAWiQHQTyHX4J4iN7fpJT7UKucCxQA';
BEGIN
  v_code := LPAD(floor(random() * 1000000)::TEXT, 6, '0');

  DELETE FROM otp_codes WHERE phone = p_phone;

  INSERT INTO otp_codes (phone, code, expires_at)
  VALUES (p_phone, v_code, now() + interval '5 minutes');

  PERFORM net.http_post(
    url     := 'https://www.traccar.org/sms/',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', v_token
    ),
    body := jsonb_build_object(
      'to',      p_phone,
      'message', 'رمز التحقق الخاص بك في ملاعب البندر: ' || v_code
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم إرسال رمز التحقق');
END;
$$;

-- التحقق من رمز OTP
CREATE OR REPLACE FUNCTION verify_otp(
  p_phone   TEXT,
  p_code    TEXT,
  p_purpose TEXT DEFAULT 'registration'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_valid BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM otp_codes
    WHERE phone = p_phone
      AND code = p_code
      AND expires_at > now()
  ) INTO v_valid;

  IF v_valid THEN
    DELETE FROM otp_codes WHERE phone = p_phone;
    UPDATE profiles SET phone_verified = true WHERE phone = p_phone;
    RETURN jsonb_build_object('success', true, 'message', 'تم التحقق بنجاح');
  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'رمز غير صحيح أو منتهي الصلاحية');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_otp TO anon, authenticated;

-- بعد التحقق من OTP، تعيين phone_verified = true (للمستخدم المسجل)
CREATE OR REPLACE FUNCTION set_phone_verified()
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
  UPDATE profiles SET phone_verified = true WHERE id = v_user_id;
  RETURN jsonb_build_object('success', true, 'message', 'تم التحقق');
END;
$$;

GRANT EXECUTE ON FUNCTION set_phone_verified TO authenticated;

NOTIFY pgrst, 'reload schema';
