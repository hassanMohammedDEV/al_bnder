-- ============================================================
-- AL BNDR - SUPABASE FUNCTIONS (Phase 2)
-- Response format: { success, message, data }
-- ============================================================

-- -------------------------------------------------------
-- 1. GENERATE OTP
-- POST /rest/v1/rpc/generate_otp
-- Body: { "phone": "9665xxxxxxxx", "purpose": "registration" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_otp(
  p_phone   TEXT,
  p_purpose TEXT DEFAULT 'registration'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF p_purpose NOT IN ('registration', 'login', 'password_reset') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'نوع التحقق غير صالح',
      'data', null
    );
  END IF;

  UPDATE otp_codes
  SET is_used = true
  WHERE phone = p_phone
    AND purpose = p_purpose
    AND is_used = false
    AND expires_at > now();

  -- Dev mode: fixed OTP
  v_code := '000000';
  v_expires_at := now() + INTERVAL '5 minutes';

  INSERT INTO otp_codes (phone, code, purpose, expires_at)
  VALUES (p_phone, v_code, p_purpose, v_expires_at);

  -- TODO: Integrate SMS gateway here

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إرسال رمز التحقق',
    'data', jsonb_build_object(
      'expires_at', v_expires_at
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 2. VERIFY OTP
-- POST /rest/v1/rpc/verify_otp
-- Body: { "phone": "9665xxxxxxxx", "code": "123456", "purpose": "registration" }
-- -------------------------------------------------------
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
  v_otp otp_codes%ROWTYPE;
BEGIN
  SELECT * INTO v_otp
  FROM otp_codes
  WHERE phone = p_phone
    AND code = p_code
    AND purpose = p_purpose
    AND is_used = false
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'رمز التحقق غير صالح أو منتهي الصلاحية',
      'data', null
    );
  END IF;

  UPDATE otp_codes SET is_used = true WHERE id = v_otp.id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم التحقق بنجاح',
    'data', null
  );
END;
$$;


-- -------------------------------------------------------
-- 3. CREATE BOOKING (with race condition protection)
-- POST /rest/v1/rpc/create_booking
-- Body: {
--   "facility_id": "uuid",
--   "start_at": "2026-06-25T16:00:00Z",
--   "end_at": "2026-06-25T18:00:00Z",
--   "is_recurring": false,
--   "recurring_rule": null
-- }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION create_booking(
  p_facility_id    UUID,
  p_start_at       TIMESTAMPTZ,
  p_end_at         TIMESTAMPTZ,
  p_is_recurring   BOOLEAN DEFAULT false,
  p_recurring_rule JSONB   DEFAULT null
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
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى تسجيل الدخول أولاً', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود أو غير نشط', 'data', null);
  END IF;

  v_group_id := v_facility.group_id;

  IF p_end_at <= p_start_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية يجب أن يكون بعد وقت البداية', 'data', null);
  END IF;

  -- Advisory lock
  v_lock_key := hashtext(p_facility_id::TEXT || p_start_at::TEXT);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Check overlapping
  IF EXISTS (
    SELECT 1 FROM booking_instances bi
    WHERE bi.facility_id = p_facility_id
      AND bi.status IN ('confirmed', 'pending')
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

  -- Create booking
  IF p_is_recurring AND p_recurring_rule IS NOT NULL THEN
    INSERT INTO bookings (user_id, facility_id, total_price, status, payment_status,
                          is_recurring, recurring_rule)
    VALUES (v_user_id, p_facility_id, 0, 'pending', 'unpaid', true, p_recurring_rule)
    RETURNING id INTO v_booking_id;

    v_instances := generate_recurring_dates(p_start_at, p_recurring_rule);

    FOREACH v_instance IN ARRAY v_instances
    LOOP
      v_instance_end := v_instance + (p_end_at - p_start_at);
      v_hours := EXTRACT(EPOCH FROM (v_instance_end - v_instance)) / 3600;
      INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
      VALUES (v_booking_id, p_facility_id, v_instance, v_instance_end,
              v_hours * v_facility.price_per_hour, 'pending');
    END LOOP;

    SELECT COALESCE(SUM(price), 0) INTO v_total_price
    FROM booking_instances WHERE booking_id = v_booking_id;

    UPDATE bookings SET total_price = v_total_price WHERE id = v_booking_id;

    SELECT COUNT(*) INTO v_instance_count
    FROM booking_instances WHERE booking_id = v_booking_id;
  ELSE
    v_hours := EXTRACT(EPOCH FROM (p_end_at - p_start_at)) / 3600;
    v_total_price := v_hours * v_facility.price_per_hour;

    INSERT INTO bookings (user_id, facility_id, total_price, status, payment_status)
    VALUES (v_user_id, p_facility_id, v_total_price, 'pending', 'unpaid')
    RETURNING id INTO v_booking_id;

    INSERT INTO booking_instances (booking_id, facility_id, start_at, end_at, price, status)
    VALUES (v_booking_id, p_facility_id, p_start_at, p_end_at, v_total_price, 'pending');

    v_instance_count := 1;
  END IF;

  -- Check wallet for auto-confirm
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_user_id AND facility_group_id = v_group_id
  FOR UPDATE;

  IF v_wallet.balance >= v_total_price THEN
    UPDATE wallets SET balance = balance - v_total_price WHERE id = v_wallet.id
    RETURNING balance INTO v_balance_after;

    INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
    VALUES (v_wallet.id, v_total_price, 'withdrawal', 'booking', v_booking_id,
            'خصم حجز: ' || v_facility.name);

    UPDATE bookings SET status = 'confirmed', payment_status = 'paid' WHERE id = v_booking_id;
    UPDATE booking_instances SET status = 'confirmed' WHERE booking_id = v_booking_id;
    v_confirmed := true;
  ELSE
    v_balance_after := v_wallet.balance;
    v_confirmed := false;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN v_confirmed THEN 'تم تأكيد الحجز' ELSE 'الحجز معلق بانتظار تأكيد الإدارة' END,
    'data', jsonb_build_object(
      'booking_id', v_booking_id,
      'facility_name', v_facility.name,
      'total_price', v_total_price,
      'status', CASE WHEN v_confirmed THEN 'confirmed' ELSE 'pending' END,
      'payment_status', CASE WHEN v_confirmed THEN 'paid' ELSE 'unpaid' END,
      'is_recurring', p_is_recurring,
      'instance_count', v_instance_count,
      'balance_after', v_balance_after
    )
  );
END;
$$;


-- -------------------------------------------------------
-- Helper: Generate recurring dates
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_recurring_dates(
  p_start_at        TIMESTAMPTZ,
  p_recurring_rule  JSONB
)
RETURNS TIMESTAMPTZ[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_dates        TIMESTAMPTZ[];
  v_frequency    TEXT;
  v_days_of_week INT[];
  v_end_date     DATE;
  v_count        INT;
  v_current      DATE;
  v_day_of_week  INT;
  v_start_time   TIME;
BEGIN
  v_frequency := p_recurring_rule->>'frequency';
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


-- -------------------------------------------------------
-- 4. ADMIN CONFIRM BOOKING (external payment via WhatsApp)
-- POST /rest/v1/rpc/admin_confirm_booking
-- Body: { "booking_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_confirm_booking(
  p_booking_id UUID
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

  IF v_booking.status != 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز ليس في حالة معلقة', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = v_booking.facility_id;
  IF v_admin_role = 'facility_admin' AND v_facility.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لمجموعتك', 'data', null);
  END IF;

  UPDATE bookings SET status = 'confirmed', updated_at = now() WHERE id = p_booking_id;
  UPDATE booking_instances SET status = 'confirmed' WHERE booking_id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تأكيد الحجز',
    'data', jsonb_build_object(
      'booking_id', p_booking_id,
      'status', 'confirmed'
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 5. ADMIN DEPOSIT TO WALLET
-- POST /rest/v1/rpc/admin_deposit_wallet
-- Body: {
--   "target_user_id": "uuid",
--   "facility_group_id": "uuid",
--   "amount": 100.00,
--   "description": "تم الشحن عبر واتساب"
-- }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_deposit_wallet(
  p_target_user_id    UUID,
  p_facility_group_id UUID,
  p_amount            DECIMAL(10,2),
  p_description       TEXT DEFAULT NULL
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
  v_wallet_id   UUID;
  v_new_balance DECIMAL(10,2);
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

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'المبلغ يجب أن يكون أكبر من صفر', 'data', null);
  END IF;

  INSERT INTO wallets (user_id, facility_group_id, balance)
  VALUES (p_target_user_id, p_facility_group_id, 0)
  ON CONFLICT (user_id, facility_group_id) DO NOTHING;

  SELECT id, balance INTO v_wallet_id, v_new_balance
  FROM wallets
  WHERE user_id = p_target_user_id AND facility_group_id = p_facility_group_id
  FOR UPDATE;

  UPDATE wallets SET balance = balance + p_amount WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, description)
  VALUES (v_wallet_id, p_amount, 'deposit', 'admin_deposit',
          COALESCE(p_description, 'شحن رصيد بواسطة المشرف'));

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم شحن المحفظة بنجاح',
    'data', jsonb_build_object(
      'wallet_id', v_wallet_id,
      'amount_added', p_amount,
      'new_balance', v_new_balance
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 6. CANCEL BOOKING
-- POST /rest/v1/rpc/cancel_booking
-- Body: { "booking_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION cancel_booking(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      UUID;
  v_user_role    TEXT;
  v_user_group   UUID;
  v_booking      bookings%ROWTYPE;
  v_wallet_id    UUID;
  v_facility     facilities%ROWTYPE;
  v_refunded     BOOLEAN := false;
BEGIN
  v_user_id := auth.uid();
  SELECT role, facility_group_id INTO v_user_role, v_user_group
  FROM profiles WHERE id = v_user_id;

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود', 'data', null);
  END IF;

  -- Permission check
  IF v_user_role = 'user' AND v_booking.user_id != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لك', 'data', null);
  END IF;

  IF v_user_role = 'facility_admin' THEN
    SELECT group_id INTO v_facility FROM facilities WHERE id = v_booking.facility_id;
    IF v_facility.group_id != v_user_group THEN
      RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لمجموعتك', 'data', null);
    END IF;
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن إلغاء حجز منتهي', 'data', null);
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز ملغي مسبقاً', 'data', null);
  END IF;

  -- Cancel instances
  UPDATE booking_instances SET status = 'cancelled'
  WHERE booking_id = p_booking_id AND status != 'cancelled';

  -- Refund if paid
  IF v_booking.payment_status = 'paid' THEN
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = v_booking.user_id AND facility_group_id IN (
      SELECT group_id FROM facilities WHERE id = v_booking.facility_id
    );

    IF FOUND THEN
      UPDATE wallets SET balance = balance + v_booking.total_price WHERE id = v_wallet_id;

      INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
      VALUES (v_wallet_id, v_booking.total_price, 'refund', 'refund', p_booking_id,
              'استرداد حجز ملغي: ' || p_booking_id::TEXT);
      v_refunded := true;
    END IF;
  END IF;

  UPDATE bookings
  SET status = 'cancelled',
      payment_status = CASE WHEN v_booking.payment_status = 'paid' THEN 'refunded' ELSE payment_status END,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN v_refunded THEN 'تم إلغاء الحجز واسترداد المبلغ' ELSE 'تم إلغاء الحجز' END,
    'data', jsonb_build_object(
      'booking_id', p_booking_id,
      'status', 'cancelled',
      'refunded', v_refunded
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 7. GET AVAILABLE SLOTS
-- POST /rest/v1/rpc/get_available_slots
-- Body: { "facility_id": "uuid", "date": "2026-06-25" }
-- -------------------------------------------------------
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
BEGIN
  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود', 'data', null);
  END IF;

  v_day_start := p_date::TIMESTAMPTZ;
  v_day_end := (p_date + 1)::TIMESTAMPTZ;

  SELECT jsonb_agg(jsonb_build_object(
    'id', bi.id,
    'start_at', bi.start_at,
    'end_at', bi.end_at,
    'status', bi.status,
    'price', bi.price
  ) ORDER BY bi.start_at) INTO v_booked_slots
  FROM booking_instances bi
  WHERE bi.facility_id = p_facility_id
    AND bi.status IN ('confirmed', 'pending')
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
      'booked_slots', v_booked_slots
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 8. GET MY WALLET
-- POST /rest/v1/rpc/get_my_wallet
-- Body: { "facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_wallet(
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_wallet    wallets%ROWTYPE;
  v_txns      JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى تسجيل الدخول أولاً', 'data', null);
  END IF;

  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_user_id AND facility_group_id = p_facility_group_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', wt.id,
    'amount', wt.amount,
    'type', wt.type,
    'reference_type', wt.reference_type,
    'reference_id', wt.reference_id,
    'description', wt.description,
    'created_at', wt.created_at
  ) ORDER BY wt.created_at DESC) INTO v_txns
  FROM wallet_transactions wt
  WHERE wt.wallet_id = v_wallet.id;

  IF v_txns IS NULL THEN
    v_txns := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object(
      'wallet_id', v_wallet.id,
      'balance', v_wallet.balance,
      'facility_group_id', v_wallet.facility_group_id,
      'transactions', v_txns
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 9. GET MY BOOKINGS
-- POST /rest/v1/rpc/get_my_bookings
-- Body: { "status": null } ← optional filter
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_bookings(
  p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID;
  v_bookings JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى تسجيل الدخول أولاً', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', b.id,
    'user_id', b.user_id,
    'facility_id', b.facility_id,
    'facility_name', f.name,
    'group_name', fg.name,
    'total_price', b.total_price,
    'status', b.status,
    'payment_status', b.payment_status,
    'is_recurring', b.is_recurring,
    'recurring_rule', b.recurring_rule,
    'created_at', b.created_at,
    'instances', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', bi.id,
        'start_at', bi.start_at,
        'end_at', bi.end_at,
        'status', bi.status,
        'qr_token', bi.qr_token
      ) ORDER BY bi.start_at)
      FROM booking_instances bi
      WHERE bi.booking_id = b.id
    )
  ) ORDER BY b.created_at DESC) INTO v_bookings
  FROM bookings b
  JOIN facilities f ON f.id = b.facility_id
  JOIN facility_groups fg ON fg.id = f.group_id
  WHERE b.user_id = v_user_id
    AND (p_status IS NULL OR b.status = p_status);

  IF v_bookings IS NULL THEN
    v_bookings := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object(
      'bookings', v_bookings
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 10. GET ADMIN DASHBOARD
-- POST /rest/v1/rpc/get_admin_dashboard
-- Body: { "facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_admin_dashboard(
  p_facility_group_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    UUID;
  v_admin_role  TEXT;
  v_admin_group UUID;
  v_group_id    UUID;
  v_stats       JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role = 'facility_admin' THEN
    v_group_id := v_admin_group;
  ELSIF v_admin_role = 'facility_viewer' THEN
    v_group_id := COALESCE(p_facility_group_id, v_admin_group);
  ELSIF v_admin_role = 'super_admin' THEN
    v_group_id := p_facility_group_id;
  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  IF v_group_id IS NULL AND v_admin_role = 'super_admin' THEN
    SELECT jsonb_agg(jsonb_build_object(
      'group_id', fg.id,
      'group_name', fg.name,
      'total_bookings', (SELECT COUNT(*) FROM bookings b
                         JOIN facilities f ON b.facility_id = f.id
                         WHERE f.group_id = fg.id),
      'confirmed_bookings', (SELECT COUNT(*) FROM bookings b
                             JOIN facilities f ON b.facility_id = f.id
                             WHERE f.group_id = fg.id AND b.status = 'confirmed'),
      'pending_bookings', (SELECT COUNT(*) FROM bookings b
                           JOIN facilities f ON b.facility_id = f.id
                           WHERE f.group_id = fg.id AND b.status = 'pending'),
      'total_revenue', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.payment_status = 'paid'),
      'total_deposits', (SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
                         JOIN wallets w ON wt.wallet_id = w.id
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit')
    )) INTO v_stats
    FROM facility_groups fg;
  ELSE
    SELECT jsonb_build_object(
      'group_id', fg.id,
      'group_name', fg.name,
      'total_bookings', (SELECT COUNT(*) FROM bookings b
                         JOIN facilities f ON b.facility_id = f.id
                         WHERE f.group_id = fg.id),
      'confirmed_bookings', (SELECT COUNT(*) FROM bookings b
                             JOIN facilities f ON b.facility_id = f.id
                             WHERE f.group_id = fg.id AND b.status = 'confirmed'),
      'pending_bookings', (SELECT COUNT(*) FROM bookings b
                           JOIN facilities f ON b.facility_id = f.id
                           WHERE f.group_id = fg.id AND b.status = 'pending'),
      'total_revenue', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.payment_status = 'paid'),
      'total_deposits', (SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
                         JOIN wallets w ON wt.wallet_id = w.id
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit')
    ) INTO v_stats
    FROM facility_groups fg
    WHERE fg.id = v_group_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب الإحصائيات بنجاح',
    'data', v_stats
  );
END;
$$;


-- -------------------------------------------------------
-- 11. GET FACILITY GROUPS
-- POST /rest/v1/rpc/get_facility_groups
-- Body: {}
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_facility_groups()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_groups JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', fg.id,
    'name', fg.name,
    'description', fg.description,
    'logo_url', fg.logo_url,
    'is_active', fg.is_active,
    'created_at', fg.created_at
  ) ORDER BY fg.created_at ASC) INTO v_groups
  FROM facility_groups fg
  WHERE fg.is_active = true;

  IF v_groups IS NULL THEN
    v_groups := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', v_groups
  );
END;
$$;


-- -------------------------------------------------------
-- 12. GET FACILITIES
-- POST /rest/v1/rpc/get_facilities
-- Body: { "p_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_facilities(
  p_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_facilities JSONB;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', f.id,
    'group_id', f.group_id,
    'name', f.name,
    'description', f.description,
    'type', f.type,
    'price_per_hour', f.price_per_hour,
    'capacity', f.capacity,
    'images', f.images,
    'is_active', f.is_active,
    'created_at', f.created_at
  ) ORDER BY f.created_at ASC) INTO v_facilities
  FROM facilities f
  WHERE f.group_id = p_group_id AND f.is_active = true;

  IF v_facilities IS NULL THEN
    v_facilities := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', v_facilities
  );
END;
$$;


-- -------------------------------------------------------
-- 13. ADMIN GET PENDING BOOKINGS
-- POST /rest/v1/rpc/admin_get_pending_bookings
-- Body: { "p_facility_group_id": null } ← optional filter
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_pending_bookings(
  p_facility_group_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    UUID;
  v_admin_role  TEXT;
  v_admin_group UUID;
  v_bookings    JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'facility_viewer', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', b.id,
    'user_id', b.user_id,
    'facility_id', b.facility_id,
    'group_id', fg.id,
    'facility_name', f.name,
    'group_name', fg.name,
    'user_name', p.name,
    'user_phone', p.phone,
    'total_price', b.total_price,
    'status', b.status,
    'payment_status', b.payment_status,
    'created_at', b.created_at,
    'instances', (
      SELECT jsonb_agg(jsonb_build_object(
        'id', bi.id,
        'start_at', bi.start_at,
        'end_at', bi.end_at,
        'status', bi.status
      ) ORDER BY bi.start_at)
      FROM booking_instances bi
      WHERE bi.booking_id = b.id
    )
  ) ORDER BY b.created_at DESC) INTO v_bookings
  FROM bookings b
  JOIN facilities f ON f.id = b.facility_id
  JOIN facility_groups fg ON fg.id = f.group_id
  JOIN profiles p ON p.id = b.user_id
  WHERE b.status = 'pending'
    AND (p_facility_group_id IS NULL OR fg.id = p_facility_group_id)
    AND (v_admin_role = 'super_admin' OR fg.id = v_admin_group);

  IF v_bookings IS NULL THEN
    v_bookings := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object('bookings', v_bookings)
  );
END;
$$;


-- -------------------------------------------------------
-- GRANT EXECUTE
-- -------------------------------------------------------
GRANT EXECUTE ON FUNCTION generate_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_deposit_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_booking TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_slots TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_my_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION get_facility_groups TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_facilities TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_get_pending_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION generate_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_deposit_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_booking TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_slots TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_my_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_dashboard TO authenticated;
