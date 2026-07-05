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
    'message', 'تم تأكيد الحجز',
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


-- -------------------------------------------------------
-- 4. ADMIN CONFIRM BOOKING (external payment via WhatsApp)
-- POST /rest/v1/rpc/admin_confirm_booking
-- Body: { "booking_id": "uuid" }
-- -------------------------------------------------------
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


-- -------------------------------------------------------
-- 4b. ADMIN CONFIRM PENDING APPROVAL BOOKING
-- POST /rest/v1/rpc/admin_confirm_pending_approval
-- Body: { "booking_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_confirm_pending_approval(
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
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود', 'data', null);
  END IF;

  IF v_booking.status != 'pending_approval' THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز ليس في حالة شبه مؤكد', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = v_booking.facility_id;
  IF v_admin_role = 'facility_admin' AND v_facility.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الحجز ليس لمجموعتك', 'data', null);
  END IF;

  UPDATE bookings SET status = 'confirmed', payment_status = 'paid', approval_deadline = NULL, updated_at = now()
  WHERE id = p_booking_id;
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
-- 4c. AUTO-CANCEL EXPIRED PENDING APPROVAL BOOKINGS
-- Run periodically via pg_cron or manually
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_cancel_expired_pending_approval()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count        INT;
  v_pending_count INT;
BEGIN
  -- Cancel expired pending_approval (deadline passed)
  UPDATE bookings SET
    status = 'cancelled',
    payment_status = 'unpaid',
    updated_at = now()
  WHERE status = 'pending_approval'
    AND approval_deadline IS NOT NULL
    AND approval_deadline < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Cancel pending (WhatsApp) whose booking time has passed
  UPDATE bookings SET
    status = 'cancelled',
    payment_status = 'unpaid',
    updated_at = now()
  WHERE status = 'pending'
    AND id IN (
      SELECT bi.booking_id
      FROM booking_instances bi
      WHERE bi.status = 'pending'
        AND bi.start_at < now()
    );

  GET DIAGNOSTICS v_pending_count = ROW_COUNT;

  UPDATE booking_instances bi SET status = 'cancelled'
  FROM bookings b
  WHERE bi.booking_id = b.id
    AND b.status = 'cancelled'
    AND bi.status IN ('pending_approval', 'pending');

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إلغاء ' || v_count || ' حجز شبه مؤكد و ' || v_pending_count || ' حجز معلق',
    'data', jsonb_build_object(
      'cancelled_count', v_count,
      'pending_cancelled_count', v_pending_count
    )
  );
END;
$$;
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

  UPDATE profiles SET facility_group_id = COALESCE(facility_group_id, p_facility_group_id)
  WHERE id = p_target_user_id;

  SELECT id, balance INTO v_wallet_id, v_new_balance
  FROM wallets
  WHERE user_id = p_target_user_id AND facility_group_id = p_facility_group_id
  FOR UPDATE;

  UPDATE wallets SET balance = balance + p_amount WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, description, created_by)
  VALUES (v_wallet_id, p_amount, 'deposit', 'admin_deposit',
          COALESCE(p_description, 'شحن رصيد بواسطة المشرف'), v_admin_id);

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
-- POST /rest/v1/rpc/admin_deduct_wallet
-- Body: {
--   "target_user_id": "uuid",
--   "facility_group_id": "uuid",
--   "amount": 100.00,
--   "description": "خصم يدوي"
-- }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_deduct_wallet(
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
  v_balance     DECIMAL(10,2);
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

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM wallets
  WHERE user_id = p_target_user_id AND facility_group_id = p_facility_group_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة', 'data', null);
  END IF;

  IF v_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'message', 'الرصيد غير كافٍ. الرصيد المتاح: ' || v_balance::TEXT, 'data', null);
  END IF;

  UPDATE wallets SET balance = balance - p_amount WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, description, created_by)
  VALUES (v_wallet_id, p_amount, 'withdrawal', 'admin_deduct',
          COALESCE(p_description, 'خصم من الرصيد بواسطة المشرف'), v_admin_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم الخصم من المحفظة بنجاح',
    'data', jsonb_build_object(
      'wallet_id', v_wallet_id,
      'amount_deducted', p_amount,
      'new_balance', v_new_balance
    )
  );
END;
$$;


-- -------------------------------------------------------
-- 5b. ADMIN CREATE BOOKING (on behalf of a user, or for a guest)
-- POST /rest/v1/rpc/admin_create_booking
-- Body: {
--   "target_user_id": null,            ← null for guest bookings
--   "target_name": "أحمد",             ← required for guest bookings
--   "target_phone": "05xxxxxxxx",      ← optional for guest bookings
--   "facility_id": "uuid",
--   "start_at": "2024-01-15T16:00:00Z",
--   "end_at": "2024-01-15T18:00:00Z",
--   "is_recurring": false,
--   "recurring_rule": null
-- }
-- -------------------------------------------------------
-- Drop all overloads of admin_create_booking to avoid duplicates
DO $$ BEGIN
  PERFORM 1 FROM pg_proc WHERE proname = 'admin_create_booking' AND pronamespace = 'public'::regnamespace;
  IF FOUND THEN
    EXECUTE (
      SELECT string_agg('DROP FUNCTION IF EXISTS ' || oid::regprocedure::TEXT, '; ')
      FROM pg_proc
      WHERE proname = 'admin_create_booking' AND pronamespace = 'public'::regnamespace
    );
  END IF;
END $$;

DROP FUNCTION IF EXISTS admin_create_booking(UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID, TEXT, TEXT, BOOLEAN, JSONB, BOOLEAN);
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

-- Add guest_name column for guest bookings (unregistered users)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS guest_name TEXT;
-- Add guest_phone column for guest bookings
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS guest_phone TEXT;
-- Make user_id nullable for guest bookings
ALTER TABLE bookings ALTER COLUMN user_id DROP NOT NULL;
-- Create developer_settlements table
CREATE TABLE IF NOT EXISTS developer_settlements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  created_by      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE
);

-- Pending approval feature
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS approval_deadline TIMESTAMPTZ;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS developer_settled BOOLEAN DEFAULT false;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS paid_amount DECIMAL(10,2) DEFAULT 0;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS is_admin_booking BOOLEAN DEFAULT false;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending', 'pending_approval', 'confirmed', 'cancelled', 'completed'));
ALTER TABLE booking_instances DROP CONSTRAINT IF EXISTS booking_instances_status_check;
ALTER TABLE booking_instances ADD CONSTRAINT booking_instances_status_check
  CHECK (status IN ('pending', 'pending_approval', 'confirmed', 'cancelled', 'completed'));


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
  v_user_id        UUID;
  v_user_role      TEXT;
  v_user_group     UUID;
  v_booking        bookings%ROWTYPE;
  v_wallet_id      UUID;
  v_facility       facilities%ROWTYPE;
  v_refunded       BOOLEAN := false;
  v_refund_amount  DECIMAL(10,2);
  v_deposit_amount DECIMAL(10,2);
  v_payment_status TEXT;
  v_first_start    TIMESTAMPTZ;
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

  -- Block user from cancelling admin-created bookings
  IF v_booking.is_admin_booking AND v_user_role = 'user' THEN
    RETURN jsonb_build_object('success', false, 'message', 'هذا الحجز تم عبر الإدارة. للإلغاء يرجى التواصل مع الإدارة.', 'data', null);
  END IF;

  -- Check if booking has already started (server time, prevents client clock tampering)
  SELECT MIN(start_at) INTO v_first_start
  FROM booking_instances
  WHERE booking_id = p_booking_id AND status != 'cancelled';

  IF v_first_start IS NOT NULL AND v_first_start <= now() THEN
    RETURN jsonb_build_object('success', false, 'message',
      'لا يمكن إلغاء حجز بعد بدء الوقت', 'data', null);
  END IF;

  -- Fetch deposit amount for this facility group
  SELECT COALESCE(deposit_amount, 5000) INTO v_deposit_amount
  FROM group_settings
  WHERE facility_group_id = (SELECT group_id FROM facilities WHERE id = v_booking.facility_id);

  -- Cancel instances
  UPDATE booking_instances SET status = 'cancelled'
  WHERE booking_id = p_booking_id AND status != 'cancelled';

  -- Refund logic
  IF v_booking.payment_status = 'paid' AND v_booking.paid_amount > 0 THEN
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = v_booking.user_id AND facility_group_id IN (
      SELECT group_id FROM facilities WHERE id = v_booking.facility_id
    );

    IF FOUND THEN
      IF v_booking.paid_amount > v_deposit_amount THEN
        v_refund_amount := v_booking.paid_amount - v_deposit_amount;
        UPDATE wallets SET balance = balance + v_refund_amount WHERE id = v_wallet_id;
        INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
        VALUES (v_wallet_id, v_refund_amount, 'refund', 'refund', p_booking_id,
                'استرداد جزئي (خصم العربون): ' || p_booking_id::TEXT);
        v_refunded := true;
        v_payment_status := 'refunded';
      ELSE
        v_refund_amount := 0;
        v_refunded := false;
        v_payment_status := 'paid';
      END IF;
    END IF;
  ELSE
    v_payment_status := v_booking.payment_status;
  END IF;

  UPDATE bookings
  SET status = 'cancelled',
      payment_status = v_payment_status,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE
      WHEN v_refunded THEN 'تم إلغاء الحجز واسترداد ' || v_refund_amount::TEXT || ' ريال (خصم العربون)'
      WHEN v_refund_amount = 0 AND v_booking.paid_amount > 0 THEN 'تم إلغاء الحجز (خصم العربون كرسوم إلغاء)'
      ELSE 'تم إلغاء الحجز'
    END,
    'data', jsonb_build_object(
      'booking_id', p_booking_id,
      'status', 'cancelled',
      'refunded', v_refunded,
      'refund_amount', v_refund_amount
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
-- Body: { "p_status": null, "p_facility_group_id": null } ← optional filters
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_bookings(
  p_status TEXT DEFAULT NULL,
  p_facility_group_id UUID DEFAULT NULL
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
    'group_id', fg.id,
    'total_price', b.total_price,
    'paid_amount', b.paid_amount,
    'status', b.status,
    'payment_status', b.payment_status,
    'is_recurring', b.is_recurring,
    'recurring_rule', b.recurring_rule,
    'created_at', b.created_at,
    'is_admin_booking', b.is_admin_booking,
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
    AND (p_status IS NULL OR b.status = p_status)
    AND (p_facility_group_id IS NULL OR fg.id = p_facility_group_id);

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
      'pending_approval_bookings', (SELECT COUNT(*) FROM bookings b
                                    JOIN facilities f ON b.facility_id = f.id
                                    WHERE f.group_id = fg.id AND b.status = 'pending_approval'),
      'total_revenue', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.payment_status = 'paid'),
      'total_deposits', (SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
                         JOIN wallets w ON wt.wallet_id = w.id
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit'),
      'developer_due', GREATEST(0, (
        SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
        JOIN facilities f ON b.facility_id = f.id
        WHERE f.group_id = fg.id AND b.status = 'confirmed'
      ) - (
        SELECT COALESCE(SUM(ds.amount), 0) FROM developer_settlements ds
        WHERE ds.facility_group_id = fg.id
      )),
      'developer_due_count', (SELECT COUNT(*) FROM bookings b
                              JOIN facilities f ON b.facility_id = f.id
                              WHERE f.group_id = fg.id AND b.status = 'confirmed'
                                AND b.developer_settled = false),
      'today_confirmed', (SELECT COUNT(*) FROM bookings b
                          JOIN facilities f ON b.facility_id = f.id
                          WHERE f.group_id = fg.id AND b.status = 'confirmed'
                            AND b.created_at >= CURRENT_DATE),
      'today_pending', (SELECT COUNT(*) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'pending'
                          AND b.created_at >= CURRENT_DATE),
      'today_pending_approval', (SELECT COUNT(*) FROM bookings b
                                JOIN facilities f ON b.facility_id = f.id
                                WHERE f.group_id = fg.id AND b.status = 'pending_approval'
                                  AND b.created_at >= CURRENT_DATE)
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
      'pending_approval_bookings', (SELECT COUNT(*) FROM bookings b
                                    JOIN facilities f ON b.facility_id = f.id
                                    WHERE f.group_id = fg.id AND b.status = 'pending_approval'),
      'total_revenue', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.payment_status = 'paid'),
      'total_deposits', (SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
                         JOIN wallets w ON wt.wallet_id = w.id
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit'),
      'developer_due', GREATEST(0, (
        SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
        JOIN facilities f ON b.facility_id = f.id
        WHERE f.group_id = fg.id AND b.status = 'confirmed'
      ) - (
        SELECT COALESCE(SUM(ds.amount), 0) FROM developer_settlements ds
        WHERE ds.facility_group_id = fg.id
      )),
      'developer_due_count', (SELECT COUNT(*) FROM bookings b
                              JOIN facilities f ON b.facility_id = f.id
                              WHERE f.group_id = fg.id AND b.status = 'confirmed'
                                AND b.developer_settled = false),
      'today_confirmed', (SELECT COUNT(*) FROM bookings b
                          JOIN facilities f ON b.facility_id = f.id
                          WHERE f.group_id = fg.id AND b.status = 'confirmed'
                            AND b.created_at >= CURRENT_DATE),
      'today_pending', (SELECT COUNT(*) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'pending'
                          AND b.created_at >= CURRENT_DATE),
      'today_pending_approval', (SELECT COUNT(*) FROM bookings b
                                JOIN facilities f ON b.facility_id = f.id
                                WHERE f.group_id = fg.id AND b.status = 'pending_approval'
                                  AND b.created_at >= CURRENT_DATE)
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
-- 10b. RECORD DEVELOPER SETTLEMENT
-- POST /rest/v1/rpc/record_developer_settlement
-- Body: { "facility_group_id": "uuid", "notes": "تسوية" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION record_developer_settlement(
  p_facility_group_id UUID,
  p_amount            DECIMAL(10,2) DEFAULT 0,
  p_notes             TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_role     TEXT;
  v_count    INT;
BEGIN
  v_admin_id := auth.uid();
  SELECT role INTO v_role FROM profiles WHERE id = v_admin_id;
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  -- Mark all unsettled confirmed bookings as settled
  UPDATE bookings SET developer_settled = true
  WHERE facility_id IN (SELECT id FROM facilities WHERE group_id = p_facility_group_id)
    AND status = 'confirmed'
    AND developer_settled = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO developer_settlements (facility_group_id, amount, notes, created_by)
  VALUES (p_facility_group_id, p_amount, COALESCE(p_notes, 'تم تسوية ' || v_count || ' حجوزات'), v_admin_id);

  RETURN jsonb_build_object('success', true, 'message', 'تم تسوية ' || v_count || ' حجوزات', 'data', null);
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
    'phone', fg.phone,
    'is_active', fg.is_active,
    'created_at', fg.created_at
  ) ORDER BY fg.is_active DESC, fg.created_at ASC) INTO v_groups
  FROM facility_groups fg;

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
    'price_per_hour', f.price_per_hour,
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
-- 12B. ADMIN GET FACILITIES (includes inactive)
-- POST /rest/v1/rpc/admin_get_facilities
-- Body: { "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_facilities(
  p_facility_group_id UUID
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
  v_facilities  JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'facility_viewer', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  IF v_admin_role != 'super_admin' AND v_admin_group != p_facility_group_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذه المجموعة ليست لمجموعتك', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', f.id,
    'group_id', f.group_id,
    'name', f.name,
    'description', f.description,
    'price_per_hour', f.price_per_hour,
    'images', f.images,
    'is_active', f.is_active,
    'created_at', f.created_at
  ) ORDER BY f.created_at ASC) INTO v_facilities
  FROM facilities f
  WHERE f.group_id = p_facility_group_id;

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
-- 12C. UPDATE FACILITY
-- POST /rest/v1/rpc/update_facility
-- Body: { "p_facility_id": "uuid", "p_name": "text", "p_description": "text", "p_price_per_hour": 100.00 }
-- -------------------------------------------------------
DO $$ BEGIN
  DROP FUNCTION IF EXISTS update_facility(UUID, TEXT, TEXT, DECIMAL);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  DROP FUNCTION IF EXISTS update_facility(UUID, TEXT, TEXT, DECIMAL, BOOLEAN);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
CREATE OR REPLACE FUNCTION update_facility(
  p_facility_id    UUID,
  p_name           TEXT,
  p_description    TEXT DEFAULT NULL,
  p_price_per_hour DECIMAL DEFAULT NULL,
  p_is_active      BOOLEAN DEFAULT NULL
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
  v_facility    facilities%ROWTYPE;
BEGIN
  v_admin_id := auth.uid();
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'facility_viewer', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT * INTO v_facility FROM facilities WHERE id = p_facility_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب غير موجود', 'data', null);
  END IF;

  IF v_admin_role != 'super_admin' AND v_facility.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذا الملعب ليس لمجموعتك', 'data', null);
  END IF;

  UPDATE facilities SET
    name           = COALESCE(p_name, name),
    description    = COALESCE(p_description, description),
    price_per_hour = COALESCE(p_price_per_hour, price_per_hour),
    is_active      = COALESCE(p_is_active, is_active),
    updated_at     = now()
  WHERE id = p_facility_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تحديث بيانات الملعب بنجاح',
    'data', null
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
    'guest_name', b.guest_name,
    'guest_phone', b.guest_phone,
    'facility_id', b.facility_id,
    'group_id', fg.id,
    'facility_name', f.name,
    'group_name', fg.name,
    'user_name', COALESCE(p.full_name, b.guest_name),
    'user_phone', COALESCE(p.phone, b.guest_phone),
    'total_price', b.total_price,
    'paid_amount', b.paid_amount,
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
  LEFT JOIN profiles p ON p.id = b.user_id
  WHERE b.status IN ('pending', 'pending_approval')
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
-- Helper: check if a booking is within group's working hours
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION is_within_working_hours(
  p_facility_group_id UUID,
  p_start_at TIMESTAMPTZ,
  p_end_at TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
SET timezone = 'Asia/Aden'
AS $$
DECLARE
  v_dow     INT;
  v_open    TIME;
  v_close   TIME;
BEGIN
  -- Get the opening time first
  SELECT opening_time INTO v_open
  FROM group_settings
  WHERE facility_group_id = p_facility_group_id;

  IF v_open IS NULL THEN
    RETURN true;
  END IF;

  -- Determine the "session date": if start is before the opening time
  -- (after midnight in a cross-midnight schedule), the session started
  -- on the previous day, so use the previous day's closing time.
  IF p_start_at::TIME < v_open THEN
    v_dow = EXTRACT(DOW FROM p_start_at - INTERVAL '1 day');
  ELSE
    v_dow = EXTRACT(DOW FROM p_start_at);
  END IF;

  SELECT
    CASE v_dow
      WHEN 0 THEN closing_time_sun
      WHEN 1 THEN closing_time_mon
      WHEN 2 THEN closing_time_tue
      WHEN 3 THEN closing_time_wed
      WHEN 4 THEN closing_time_thu
      WHEN 5 THEN closing_time_fri
      WHEN 6 THEN closing_time_sat
    END INTO v_close
  FROM group_settings
  WHERE facility_group_id = p_facility_group_id;

  IF v_close > v_open THEN
    -- same-day window
    RETURN p_start_at::TIME >= v_open AND p_end_at::TIME <= v_close
       AND p_end_at::DATE = p_start_at::DATE;
  ELSE
    -- crosses midnight (e.g., 17:00 → 02:00)
    IF p_start_at::TIME >= v_open THEN
      -- started in the evening
      RETURN p_end_at::DATE = p_start_at::DATE  -- same day (before midnight) → always valid
          OR (p_end_at::DATE > p_start_at::DATE AND p_end_at::TIME <= v_close);  -- next day → must be ≤ close
    ELSE
      -- started after midnight (early morning of the next day)
      RETURN p_start_at::TIME <= v_close
         AND p_end_at::TIME <= v_close
         AND p_end_at::DATE = p_start_at::DATE;
    END IF;
  END IF;
END;
$$;


-- -------------------------------------------------------
-- POST /rest/v1/rpc/get_group_settings
-- Body: { "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
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


-- -------------------------------------------------------
-- POST /rest/v1/rpc/upsert_group_settings
-- Body: { "p_facility_group_id": "uuid", "p_opening_time": "16:00", ... }
-- -------------------------------------------------------
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


-- -------------------------------------------------------
-- GRANT EXECUTE
-- -------------------------------------------------------
GRANT EXECUTE ON FUNCTION generate_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_otp TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_booking TO authenticated;
GRANT EXECUTE ON FUNCTION admin_deposit_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION admin_deduct_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION admin_create_booking TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_booking TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_slots TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_my_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_bookings(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION record_developer_settlement TO authenticated;
GRANT EXECUTE ON FUNCTION get_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_group_settings TO authenticated;
GRANT EXECUTE ON FUNCTION get_facilities TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_get_facilities TO authenticated;
GRANT EXECUTE ON FUNCTION update_facility TO authenticated;
-- -------------------------------------------------------
-- 13. GET TODAY BOOKINGS (for admin dashboard drill-down)
-- POST /rest/v1/rpc/admin_get_today_bookings
-- Body: { "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_today_bookings(
  p_facility_group_id UUID
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
    'guest_name', b.guest_name,
    'guest_phone', b.guest_phone,
    'facility_id', b.facility_id,
    'facility_name', f.name,
    'user_name', COALESCE(p.full_name, b.guest_name),
    'user_phone', COALESCE(p.phone, b.guest_phone),
    'total_price', b.total_price,
    'paid_amount', b.paid_amount,
    'status', b.status,
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
  LEFT JOIN profiles p ON p.id = b.user_id
  WHERE f.group_id = p_facility_group_id
    AND b.created_at >= CURRENT_DATE
    AND (v_admin_role = 'super_admin' OR f.group_id = v_admin_group);

  IF v_bookings IS NULL THEN
    v_bookings := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم جلب البيانات', 'data', v_bookings);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_today_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_pending_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_pending_approval TO authenticated;
GRANT EXECUTE ON FUNCTION auto_cancel_expired_pending_approval TO authenticated;


-- -------------------------------------------------------
-- POST /rest/v1/rpc/admin_search_bookings_by_phone
-- Body: { "p_phone_query": "77...", "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_search_bookings_by_phone(
  p_phone_query       TEXT,
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
    'guest_name', b.guest_name,
    'guest_phone', b.guest_phone,
    'facility_id', b.facility_id,
    'group_id', fg.id,
    'facility_name', f.name,
    'group_name', fg.name,
    'user_name', COALESCE(p.full_name, b.guest_name),
    'user_phone', COALESCE(p.phone, b.guest_phone),
    'total_price', b.total_price,
    'paid_amount', b.paid_amount,
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
  LEFT JOIN profiles p ON p.id = b.user_id
  WHERE COALESCE(p.phone, b.guest_phone) ILIKE '%' || p_phone_query || '%'
    AND (p_facility_group_id IS NULL OR fg.id = p_facility_group_id)
    AND (v_admin_role = 'super_admin' OR fg.id = v_admin_group);

  IF v_bookings IS NULL THEN
    v_bookings := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم جلب البيانات', 'data', v_bookings);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_search_bookings_by_phone TO authenticated;


-- -------------------------------------------------------
-- POST /rest/v1/rpc/admin_search_bookings_by_date_range
-- Body: { "p_facility_group_id": "uuid", "p_start_date": "2026-01-01", "p_end_date": "2026-12-31" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_search_bookings_by_date_range(
  p_facility_group_id UUID DEFAULT NULL,
  p_start_date        DATE   DEFAULT NULL,
  p_end_date          DATE   DEFAULT NULL
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
    'guest_name', b.guest_name,
    'guest_phone', b.guest_phone,
    'facility_id', b.facility_id,
    'group_id', fg.id,
    'facility_name', f.name,
    'group_name', fg.name,
    'user_name', COALESCE(p.full_name, b.guest_name),
    'user_phone', COALESCE(p.phone, b.guest_phone),
    'total_price', b.total_price,
    'status', b.status,
    'payment_status', b.payment_status,
    'paid_amount', b.paid_amount,
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
  LEFT JOIN profiles p ON p.id = b.user_id
  WHERE (p_facility_group_id IS NULL OR fg.id = p_facility_group_id)
    AND (v_admin_role = 'super_admin' OR fg.id = v_admin_group OR v_admin_group IS NULL)
    AND (p_start_date IS NULL OR EXISTS (
      SELECT 1 FROM booking_instances bi
      WHERE bi.booking_id = b.id
        AND bi.start_at >= p_start_date::TIMESTAMPTZ
        AND bi.start_at < (p_end_date + 1)::TIMESTAMPTZ
    ));

  IF v_bookings IS NULL THEN
    v_bookings := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'تم جلب البيانات', 'data', v_bookings);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_search_bookings_by_date_range TO authenticated;


-- -------------------------------------------------------
-- POST /rest/v1/rpc/admin_get_user_wallet
-- Body: { "p_target_user_id": "uuid", "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_user_wallet(
  p_target_user_id    UUID,
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_role  TEXT;
  v_admin_group UUID;
  v_wallet      wallets%ROWTYPE;
  v_txns        JSONB;
  v_name        TEXT;
  v_phone       TEXT;
BEGIN
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = auth.uid();

  IF v_admin_role NOT IN ('facility_admin', 'facility_viewer', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  IF v_admin_role != 'super_admin' AND p_facility_group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: هذه المجموعة ليست من صلاحياتك', 'data', null);
  END IF;

  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = p_target_user_id AND facility_group_id = p_facility_group_id;

  IF NOT FOUND THEN
    v_txns := '[]'::JSONB;
    RETURN jsonb_build_object('success', true, 'message', 'تم جلب البيانات', 'data', jsonb_build_object(
      'user_id', p_target_user_id,
      'balance', 0,
      'transactions', v_txns
    ));
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

  SELECT full_name, phone INTO v_name, v_phone
  FROM profiles WHERE id = p_target_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم جلب البيانات', 'data', jsonb_build_object(
    'user_id', p_target_user_id,
    'user_name', v_name,
    'user_phone', v_phone,
    'wallet_id', v_wallet.id,
    'balance', v_wallet.balance,
    'facility_group_id', v_wallet.facility_group_id,
    'transactions', v_txns
  ));
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_user_wallet TO authenticated;


-- -------------------------------------------------------
-- Schedule auto-cancel via pg_cron (runs every hour)
-- Idempotent: unschedules first, then schedules
-- -------------------------------------------------------
DO $cron$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule('auto-cancel-pending-approval');
  PERFORM cron.schedule(
    'auto-cancel-pending-approval',
    '0 * * * *',
    $cron_task$SELECT auto_cancel_expired_pending_approval()$cron_task$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, auto-cancel scheduling skipped. Run manually: SELECT auto_cancel_expired_pending_approval();';
END;
$cron$;


-- -------------------------------------------------------
-- Look up booking by QR token (for scanner)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_get_booking_by_qr_token(
  p_qr_token TEXT,
  p_facility_group_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking JSONB;
  v_admin_group UUID;
  v_admin_role TEXT;
BEGIN
  -- Get caller info
  SELECT role, facility_group_id INTO v_admin_role, v_admin_group
  FROM profiles WHERE id = auth.uid();

  -- Permission: super_admin or same group
  IF v_admin_role NOT IN ('super_admin', 'facility_admin', 'facility_viewer') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  -- Look up the booking instance by qr_token
  SELECT jsonb_build_object(
    'success', true,
    'message', 'تم العثور على الحجز',
    'data', jsonb_build_object(
      'booking_id', b.id,
      'instance_id', bi.id,
      'user_name', COALESCE(p.full_name, b.guest_name),
      'user_phone', COALESCE(p.phone, b.guest_phone),
      'facility_name', f.name,
      'group_name', fg.name,
      'start_at', bi.start_at,
      'end_at', bi.end_at,
      'status', bi.status,
      'total_price', b.total_price,
      'paid_amount', b.paid_amount,
      'qr_token', bi.qr_token,
      'created_at', b.created_at
    )
  ) INTO v_booking
  FROM booking_instances bi
  JOIN bookings b ON b.id = bi.booking_id
  JOIN facilities f ON f.id = b.facility_id
  JOIN facility_groups fg ON fg.id = f.group_id
  LEFT JOIN profiles p ON p.id = b.user_id
  WHERE bi.qr_token = p_qr_token
    AND (v_admin_role = 'super_admin' OR fg.id = v_admin_group)
    AND (p_facility_group_id IS NULL OR fg.id = p_facility_group_id);

  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود');
  END IF;

  RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_booking_by_qr_token TO authenticated;

-- ===== Announcements Feature =====

CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS announcement_reads (
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (announcement_id, user_id)
);

ALTER TABLE announcement_reads ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to see announcements
DROP POLICY IF EXISTS "announcements_select" ON announcements;
CREATE POLICY "announcements_select" ON announcements
  FOR SELECT USING (auth.role() = 'authenticated');

-- Only admin/super_admin can insert
DROP POLICY IF EXISTS "announcements_insert" ON announcements;
CREATE POLICY "announcements_insert" ON announcements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' IN ('facility_admin', 'super_admin')
    )
  );

-- Allow all authenticated users to read/write their own read markers
DROP POLICY IF EXISTS "announcement_reads_select" ON announcement_reads;
CREATE POLICY "announcement_reads_select" ON announcement_reads
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "announcement_reads_insert" ON announcement_reads;
CREATE POLICY "announcement_reads_insert" ON announcement_reads
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ===== RPC: create_announcement =====
CREATE OR REPLACE FUNCTION create_announcement(p_title TEXT, p_body TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_announcement_id UUID;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  INSERT INTO announcements (sender_id, title, body)
  VALUES (v_user_id, p_title, p_body)
  RETURNING id INTO v_announcement_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم إرسال الإشعار', 'data', jsonb_build_object('id', v_announcement_id));
END;
$$;

GRANT EXECUTE ON FUNCTION create_announcement TO authenticated;

-- ===== RPC: get_my_announcements =====
CREATE OR REPLACE FUNCTION get_my_announcements()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
BEGIN
  v_user_id := auth.uid();

  SELECT jsonb_build_object(
    'success', true,
    'data', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'sender_id', a.sender_id,
          'sender_name', COALESCE(p.full_name, ''),
          'title', a.title,
          'body', a.body,
          'created_at', a.created_at,
          'is_read', ar.announcement_id IS NOT NULL,
          'read_at', ar.read_at
        ) ORDER BY a.created_at DESC
      ), '[]'::jsonb
    )
  ) INTO v_result
  FROM announcements a
  LEFT JOIN profiles p ON p.id = a.sender_id
  LEFT JOIN announcement_reads ar ON ar.announcement_id = a.id AND ar.user_id = v_user_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_announcements TO authenticated;

-- ===== RPC: mark_announcements_read =====
CREATE OR REPLACE FUNCTION mark_announcements_read(p_announcement_ids UUID[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  INSERT INTO announcement_reads (announcement_id, user_id)
  SELECT unnest(p_announcement_ids), v_user_id
  ON CONFLICT (announcement_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'message', 'تم');
END;
$$;

GRANT EXECUTE ON FUNCTION mark_announcements_read TO authenticated;

-- ===== RPC: get_unread_announcement_count =====
CREATE OR REPLACE FUNCTION get_unread_announcement_count()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_count BIGINT;
BEGIN
  v_user_id := auth.uid();

  SELECT COUNT(*) INTO v_count
  FROM announcements a
  LEFT JOIN announcement_reads ar ON ar.announcement_id = a.id AND ar.user_id = v_user_id
  WHERE ar.announcement_id IS NULL;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('count', v_count));
END;
$$;

GRANT EXECUTE ON FUNCTION get_unread_announcement_count TO authenticated;

-- ===== RPC: delete_announcement =====
CREATE OR REPLACE FUNCTION delete_announcement(p_announcement_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_role TEXT;
  v_sender_id UUID;
BEGIN
  v_user_id := auth.uid();
  v_role := COALESCE((SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = v_user_id), '');

  SELECT sender_id INTO v_sender_id FROM announcements WHERE id = p_announcement_id;
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'الإشعار غير موجود');
  END IF;

  IF v_role = 'super_admin' OR v_sender_id = v_user_id THEN
    DELETE FROM announcements WHERE id = p_announcement_id;
    RETURN jsonb_build_object('success', true, 'message', 'تم حذف الإشعار');
  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'ليس لديك صلاحية حذف هذا الإشعار');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_announcement TO authenticated;

-- Add phone column for WhatsApp contact
ALTER TABLE facility_groups ADD COLUMN IF NOT EXISTS phone TEXT;

-- Add created_by column to track admin actions on wallets
ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- ===== RPC: get_group_available_slots =====
CREATE OR REPLACE FUNCTION get_group_available_slots(
  p_facility_group_id UUID,
  p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day_start TIMESTAMPTZ;
  v_day_end TIMESTAMPTZ;
  v_open TEXT;
  v_close TEXT;
  v_group_name TEXT;
  v_facilities JSONB;
BEGIN
  v_day_start := p_date::TIMESTAMPTZ;
  v_day_end := (p_date + 1)::TIMESTAMPTZ;

  SELECT name INTO v_group_name FROM facility_groups WHERE id = p_facility_group_id;

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
  WHERE facility_group_id = p_facility_group_id;

  SELECT jsonb_agg(jsonb_build_object(
    'id', f.id,
    'name', f.name,
    'price_per_hour', f.price_per_hour,
    'booked_slots', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', bi.id,
        'start_at', bi.start_at,
        'end_at', bi.end_at,
        'status', bi.status
      ) ORDER BY bi.start_at)
      FROM booking_instances bi
      WHERE bi.facility_id = f.id
        AND bi.status IN ('confirmed', 'pending', 'pending_approval')
        AND bi.start_at >= v_day_start
        AND bi.end_at <= v_day_end
    ), '[]'::jsonb)
  ) ORDER BY f.name) INTO v_facilities
  FROM facilities f
  WHERE f.group_id = p_facility_group_id AND f.is_active = true;

  IF v_facilities IS NULL THEN
    v_facilities := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'group_name', v_group_name,
      'date', p_date,
      'opening_time', v_open,
      'closing_time', v_close,
      'facilities', v_facilities
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_group_available_slots TO authenticated;

-- ===== RPC: get_wallet_operations_report =====
CREATE OR REPLACE FUNCTION get_wallet_operations_report(
  p_facility_group_id UUID,
  p_start_date DATE,
  p_end_date DATE
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
  v_operations  JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT raw_user_meta_data->>'role', raw_user_meta_data->>'facility_group_id'
  INTO v_admin_role, v_admin_group::TEXT
  FROM auth.users WHERE id = v_admin_id;
  v_admin_group := v_admin_group::UUID;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin', 'facility_viewer') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', wt.id,
    'type', wt.type,
    'amount', wt.amount,
    'description', wt.description,
    'created_at', wt.created_at,
    'target_user_name', COALESCE(p.full_name, ''),
    'target_user_phone', COALESCE(p.phone, ''),
    'admin_name', COALESCE(a.full_name, '')
  ) ORDER BY wt.created_at DESC) INTO v_operations
  FROM wallet_transactions wt
  JOIN wallets w ON w.id = wt.wallet_id
  JOIN profiles p ON p.id = w.user_id
  LEFT JOIN profiles a ON a.id = wt.created_by
  WHERE w.facility_group_id = p_facility_group_id
    AND wt.reference_type IN ('admin_deposit', 'admin_deduct')
    AND wt.created_at >= p_start_date::TIMESTAMPTZ
    AND wt.created_at < (p_end_date + 1)::TIMESTAMPTZ
    AND (v_admin_role = 'super_admin' OR w.facility_group_id = v_admin_group);

  IF v_operations IS NULL THEN
    v_operations := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', v_operations);
END;
$$;

GRANT EXECUTE ON FUNCTION get_wallet_operations_report TO authenticated;

-- =============================================
-- ADMIN SHRINK BOOKING
-- =============================================
CREATE OR REPLACE FUNCTION admin_shrink_booking(
  p_booking_id   UUID,
  p_new_end_at   TIMESTAMPTZ
) RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id      UUID;
  v_admin_role    TEXT;
  v_admin_group   UUID;
  v_booking       RECORD;
  v_instance      RECORD;
  v_facility      RECORD;
  v_old_minutes   NUMERIC;
  v_new_minutes   NUMERIC;
  v_old_price     NUMERIC(10,2);
  v_new_price     NUMERIC(10,2);
  v_refund        NUMERIC(10,2) := 0;
  v_wallet_id     UUID;
  v_deposit_amt   NUMERIC(10,2);
BEGIN
  v_admin_id := auth.uid();
  SELECT raw_user_meta_data->>'role', raw_user_meta_data->>'facility_group_id'
  INTO v_admin_role, v_admin_group::TEXT
  FROM auth.users WHERE id = v_admin_id;
  v_admin_group := v_admin_group::UUID;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  SELECT b.*, f.group_id, f.price_per_hour
  INTO v_booking
  FROM bookings b
  JOIN facilities f ON f.id = b.facility_id
  WHERE b.id = p_booking_id
  FOR UPDATE OF b;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود');
  END IF;

  IF v_booking.status IN ('cancelled', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن تعديل حجز ملغي أو منتهي');
  END IF;

  IF v_admin_role != 'super_admin' AND v_booking.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح بهذا الحجز');
  END IF;

  SELECT * INTO v_instance
  FROM booking_instances
  WHERE booking_id = p_booking_id
  ORDER BY start_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا توجد تفاصيل للحجز');
  END IF;

  IF p_new_end_at <= v_instance.start_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية الجديد يجب أن يكون بعد وقت البداية');
  END IF;

  IF p_new_end_at >= v_instance.end_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية الجديد يجب أن يكون أقل من وقت النهاية الحالي');
  END IF;

  IF v_instance.status IN ('cancelled', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن تعديل حجز ملغي أو منتهي');
  END IF;

  v_old_minutes := EXTRACT(EPOCH FROM (v_instance.end_at - v_instance.start_at)) / 60;
  v_new_minutes := EXTRACT(EPOCH FROM (p_new_end_at - v_instance.start_at)) / 60;
  v_old_price := v_instance.price;
  v_new_price := ROUND((v_old_price * v_new_minutes / v_old_minutes)::NUMERIC, 2);

  -- Refund logic for full payment bookings
  IF v_booking.payment_status = 'paid'
     AND v_booking.paid_amount >= v_booking.total_price
     AND v_booking.is_admin_booking = false
  THEN
    v_refund := v_old_price - v_new_price;
    IF v_refund > 0 THEN
      SELECT id INTO v_wallet_id
      FROM wallets
      WHERE user_id = v_booking.user_id
        AND facility_group_id = v_booking.group_id;

      IF FOUND THEN
        UPDATE wallets SET balance = balance + v_refund WHERE id = v_wallet_id;
        INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description, created_by)
        VALUES (v_wallet_id, v_refund, 'refund', 'refund', p_booking_id,
                'استرداد تقليص حجز: ' || p_booking_id::TEXT, v_admin_id);
      END IF;

      -- Update booking payment_status to partially refunded
      UPDATE bookings
      SET payment_status = 'refunded',
          updated_at = now()
      WHERE id = p_booking_id;
    END IF;
  END IF;

  -- Update the instance
  UPDATE booking_instances
  SET end_at = p_new_end_at,
      price = v_new_price
  WHERE id = v_instance.id;

  -- Update booking total_price (recalculate from all instances)
  UPDATE bookings
  SET total_price = (
    SELECT COALESCE(SUM(price), 0)
    FROM booking_instances
    WHERE booking_id = p_booking_id
  ),
  updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تقليص الحجز بنجاح',
    'refund_amount', v_refund,
    'old_price', v_old_price,
    'new_price', v_new_price
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_shrink_booking TO authenticated;

-- ===== Advertisements Feature (using user's advertisements table) =====

ALTER TABLE public.advertisements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "advertisements_select" ON public.advertisements;
CREATE POLICY "advertisements_select" ON public.advertisements
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "advertisements_insert" ON public.advertisements;
CREATE POLICY "advertisements_insert" ON public.advertisements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' IN ('facility_admin', 'super_admin')
    )
  );

DROP POLICY IF EXISTS "advertisements_update" ON public.advertisements;
CREATE POLICY "advertisements_update" ON public.advertisements
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' IN ('facility_admin', 'super_admin')
    )
  );

DROP POLICY IF EXISTS "advertisements_delete" ON public.advertisements;
CREATE POLICY "advertisements_delete" ON public.advertisements
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' IN ('facility_admin', 'super_admin')
    )
  );

-- ===== RPC: get_advertisements =====
CREATE OR REPLACE FUNCTION get_advertisements(p_facility_group_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'success', true,
    'data', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'facility_group_id', a.facility_group_id,
          'title', a.title,
          'description', a.description,
          'image_url', a.image_url,
          'link_url', a.link_url,
          'is_active', a.is_active,
          'starts_at', a.starts_at,
          'ends_at', a.ends_at,
          'created_at', a.created_at,
          'updated_at', a.updated_at,
          'sort_order', a.sort_order
        ) ORDER BY a.sort_order ASC, a.created_at DESC
      ), '[]'::jsonb
    )
  ) INTO v_result
  FROM public.advertisements a
  WHERE a.facility_group_id = p_facility_group_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_advertisements TO authenticated;

-- ===== RPC: get_active_advertisements =====
CREATE OR REPLACE FUNCTION get_active_advertisements(p_facility_group_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_now TIMESTAMPTZ;
BEGIN
  v_now := now();
  SELECT jsonb_build_object(
    'success', true,
    'data', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'facility_group_id', a.facility_group_id,
          'title', a.title,
          'description', a.description,
          'image_url', a.image_url,
          'link_url', a.link_url,
          'is_active', a.is_active,
          'starts_at', a.starts_at,
          'ends_at', a.ends_at,
          'created_at', a.created_at,
          'updated_at', a.updated_at,
          'sort_order', a.sort_order
        ) ORDER BY a.sort_order ASC, a.created_at DESC
      ), '[]'::jsonb
    )
  ) INTO v_result
  FROM public.advertisements a
  WHERE a.facility_group_id = p_facility_group_id
    AND a.is_active = true
    AND (a.starts_at IS NULL OR a.starts_at <= v_now)
    AND (a.ends_at IS NULL OR a.ends_at > v_now);

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_active_advertisements TO authenticated;

-- ===== RPC: get_all_active_advertisements =====
CREATE OR REPLACE FUNCTION get_all_active_advertisements()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_now TIMESTAMPTZ;
BEGIN
  v_now := now();
  SELECT jsonb_build_object(
    'success', true,
    'data', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'facility_group_id', a.facility_group_id,
          'title', a.title,
          'description', a.description,
          'image_url', a.image_url,
          'link_url', a.link_url,
          'is_active', a.is_active,
          'starts_at', a.starts_at,
          'ends_at', a.ends_at,
          'created_at', a.created_at,
          'updated_at', a.updated_at,
          'sort_order', a.sort_order
        ) ORDER BY a.sort_order ASC, a.created_at DESC
      ), '[]'::jsonb
    )
  ) INTO v_result
  FROM public.advertisements a
  WHERE a.is_active = true
    AND (a.starts_at IS NULL OR a.starts_at <= v_now)
    AND (a.ends_at IS NULL OR a.ends_at > v_now);

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_active_advertisements TO authenticated;

-- ===== RPC: admin_reschedule_booking =====
CREATE OR REPLACE FUNCTION admin_reschedule_booking(
  p_booking_id   UUID,
  p_new_start_at TIMESTAMPTZ,
  p_new_end_at   TIMESTAMPTZ
) RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id      UUID;
  v_admin_role    TEXT;
  v_admin_group   UUID;
  v_booking       RECORD;
  v_first         RECORD;
  v_instance      RECORD;
  v_facility      RECORD;
  v_old_minutes   NUMERIC;
  v_new_minutes   NUMERIC;
  v_new_price     NUMERIC(10,2);
  v_delta_start   INTERVAL;
  v_delta_end     INTERVAL;
  v_refund        NUMERIC(10,2) := 0;
  v_wallet_id     UUID;
  v_lock_key      BIGINT;
BEGIN
  v_admin_id := auth.uid();

  SELECT raw_user_meta_data->>'role', raw_user_meta_data->>'facility_group_id'
  INTO v_admin_role, v_admin_group::TEXT
  FROM auth.users WHERE id = v_admin_id;
  v_admin_group := v_admin_group::UUID;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  IF p_new_end_at <= p_new_start_at THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت النهاية يجب أن يكون بعد وقت البداية');
  END IF;

  SELECT b.*, f.group_id, f.price_per_hour, f.id AS fac_id
  INTO v_booking
  FROM bookings b
  JOIN facilities f ON f.id = b.facility_id
  WHERE b.id = p_booking_id
  FOR UPDATE OF b;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود');
  END IF;

  IF v_booking.status IN ('cancelled', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن تعديل حجز ملغي أو منتهي');
  END IF;

  IF v_admin_role != 'super_admin' AND v_booking.group_id != v_admin_group THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح بهذا الحجز');
  END IF;

  IF NOT is_within_working_hours(v_booking.group_id, p_new_start_at, p_new_end_at) THEN
    RETURN jsonb_build_object('success', false, 'message', 'الوقت الجديد خارج أوقات العمل');
  END IF;

  -- Get first instance to calculate delta
  SELECT * INTO v_first
  FROM booking_instances
  WHERE booking_id = p_booking_id
  ORDER BY start_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا توجد تفاصيل للحجز');
  END IF;

  IF v_first.status IN ('cancelled', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'لا يمكن تعديل حجز ملغي أو منتهي');
  END IF;

  -- Calculate shift delta
  v_delta_start := p_new_start_at - v_first.start_at;
  v_delta_end := p_new_end_at - v_first.end_at;

  -- Check availability for ALL instances at new times (exclude current booking)
  FOR v_instance IN
    SELECT * FROM booking_instances
    WHERE booking_id = p_booking_id
    ORDER BY start_at ASC
  LOOP
    v_lock_key := hashtext(v_booking.fac_id::TEXT || v_instance.id::TEXT);
    PERFORM pg_advisory_xact_lock(v_lock_key);

    IF EXISTS (
      SELECT 1 FROM booking_instances bi
      WHERE bi.facility_id = v_booking.fac_id
        AND bi.status IN ('confirmed', 'pending', 'pending_approval')
        AND bi.start_at < (v_instance.end_at + v_delta_end)
        AND bi.end_at > (v_instance.start_at + v_delta_start)
        AND bi.booking_id != p_booking_id
        FOR UPDATE
    ) THEN
      RETURN jsonb_build_object('success', false, 'message',
        'الوقت الجديد محجوز مسبقاً: ' || (v_instance.start_at + v_delta_start)::TEXT);
    END IF;
  END LOOP;

  -- Recalculate price proportionally (based on first instance)
  v_old_minutes := EXTRACT(EPOCH FROM (v_first.end_at - v_first.start_at)) / 60;
  v_new_minutes := EXTRACT(EPOCH FROM (p_new_end_at - p_new_start_at)) / 60;

  -- Compute total refund: old_total - new_total across all instances
  IF v_booking.payment_status = 'paid'
     AND v_booking.paid_amount >= v_booking.total_price
     AND v_booking.is_admin_booking = false
  THEN
    SELECT
      COALESCE(SUM(bi.price), 0) -
      COALESCE(SUM(ROUND((bi.price * v_new_minutes / v_old_minutes)::NUMERIC, 2)), 0)
    INTO v_refund
    FROM booking_instances bi
    WHERE bi.booking_id = p_booking_id
      AND bi.status NOT IN ('cancelled', 'completed');

    IF v_refund <= 0 THEN v_refund := 0; END IF;
    IF v_refund > 0 THEN
      SELECT id INTO v_wallet_id
      FROM wallets
      WHERE user_id = v_booking.user_id
        AND facility_group_id = v_booking.group_id;

      IF FOUND THEN
        UPDATE wallets SET balance = balance + v_refund WHERE id = v_wallet_id;
        INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description, created_by)
        VALUES (v_wallet_id, v_refund, 'refund', 'refund', p_booking_id,
                'استرداد تعديل حجز: ' || p_booking_id::TEXT, v_admin_id);
      END IF;

      UPDATE bookings
      SET payment_status = 'refunded',
          updated_at = now()
      WHERE id = p_booking_id;
    END IF;
  END IF;

  -- Update ALL instances with shifted times + recalculated price
  FOR v_instance IN
    SELECT * FROM booking_instances
    WHERE booking_id = p_booking_id
    ORDER BY start_at ASC
  LOOP
    UPDATE booking_instances
    SET start_at = v_instance.start_at + v_delta_start,
        end_at = v_instance.end_at + v_delta_end,
        price = ROUND((v_instance.price * v_new_minutes / v_old_minutes)::NUMERIC, 2)
    WHERE id = v_instance.id;
  END LOOP;

  -- Update booking total_price
  UPDATE bookings
  SET total_price = (
    SELECT COALESCE(SUM(price), 0)
    FROM booking_instances
    WHERE booking_id = p_booking_id
  ),
  updated_at = now()
  WHERE id = p_booking_id;

  v_new_price := ROUND((v_first.price * v_new_minutes / v_old_minutes)::NUMERIC, 2);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تعديل الحجز بنجاح',
    'refund_amount', v_refund,
    'old_price', v_first.price,
    'new_price', v_new_price
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_reschedule_booking TO authenticated;

-- ===== RPC: create_advertisement =====
DROP FUNCTION IF EXISTS create_advertisement;
CREATE OR REPLACE FUNCTION create_advertisement(
  p_facility_group_id UUID,
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_link_url TEXT DEFAULT NULL,
  p_starts_at TIMESTAMPTZ DEFAULT NULL,
  p_ends_at TIMESTAMPTZ DEFAULT NULL,
  p_sort_order INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  INSERT INTO public.advertisements (facility_group_id, title, description, image_url, link_url, starts_at, ends_at, sort_order)
  VALUES (p_facility_group_id, p_title, p_description, p_image_url, p_link_url, p_starts_at, p_ends_at, p_sort_order);

  RETURN jsonb_build_object('success', true, 'message', 'تم إضافة الإعلان');
END;
$$;

GRANT EXECUTE ON FUNCTION create_advertisement TO authenticated;

-- ===== RPC: update_advertisement =====
DROP FUNCTION IF EXISTS update_advertisement;
CREATE OR REPLACE FUNCTION update_advertisement(
  p_ad_id UUID,
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_link_url TEXT DEFAULT NULL,
  p_starts_at TIMESTAMPTZ DEFAULT NULL,
  p_ends_at TIMESTAMPTZ DEFAULT NULL,
  p_sort_order INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  UPDATE public.advertisements
  SET title = p_title,
      description = p_description,
      image_url = p_image_url,
      link_url = p_link_url,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      sort_order = COALESCE(p_sort_order, sort_order),
      updated_at = now()
  WHERE id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم تحديث الإعلان');
END;
$$;

GRANT EXECUTE ON FUNCTION update_advertisement TO authenticated;

-- ===== RPC: toggle_advertisement_active =====
CREATE OR REPLACE FUNCTION toggle_advertisement_active(p_ad_id UUID, p_is_active BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  UPDATE public.advertisements
  SET is_active = p_is_active, updated_at = now()
  WHERE id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم تغيير حالة الإعلان');
END;
$$;

GRANT EXECUTE ON FUNCTION toggle_advertisement_active TO authenticated;

-- ===== RPC: update_ad_sort_order =====
DROP FUNCTION IF EXISTS update_ad_sort_order;
CREATE OR REPLACE FUNCTION update_ad_sort_order(p_ad_id UUID, p_sort_order INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  UPDATE public.advertisements
  SET sort_order = p_sort_order,
      updated_at = now()
  WHERE id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم تحديث الترتيب');
END;
$$;

GRANT EXECUTE ON FUNCTION update_ad_sort_order TO authenticated;

-- ===== RPC: delete_advertisement =====
CREATE OR REPLACE FUNCTION delete_advertisement(p_ad_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT raw_user_meta_data->>'role' INTO v_user_role FROM auth.users WHERE id = v_user_id;

  IF v_user_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح');
  END IF;

  DELETE FROM public.advertisements WHERE id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم حذف الإعلان');
END;
$$;

GRANT EXECUTE ON FUNCTION delete_advertisement TO authenticated;

-- -------------------------------------------------------
-- TELEGRAM NOTIFICATION ON NEW BOOKING (optional)
-- Run this separately after enabling pg_net:
--   create extension if not exists pg_net with schema extensions;
-- Replace TOKEN and CHAT_ID below with your bot credentials.
-- -------------------------------------------------------
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

  -- Build instances list
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

-- Drop per-instance trigger (replaced by direct calls in create_booking / admin_create_booking)
DROP TRIGGER IF EXISTS trg_booking_instance_telegram ON booking_instances;

-- ===== RPC: get_facility_analytics =====
DROP FUNCTION IF EXISTS get_facility_analytics;
CREATE OR REPLACE FUNCTION get_facility_analytics(
  p_facility_group_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_days INTEGER;
  v_open INT;
  v_close INT;
  v_hours_per_day INT;
BEGIN
  v_days := (p_end_date - p_start_date) + 1;

  SELECT EXTRACT(HOUR FROM opening_time)::INT,
         EXTRACT(HOUR FROM closing_time_mon)::INT
  INTO v_open, v_close
  FROM group_settings
  WHERE facility_group_id = p_facility_group_id;

  v_hours_per_day := v_close - v_open;

  WITH facility_list AS (
    SELECT id, name FROM facilities WHERE group_id = p_facility_group_id
  ),
  booked AS (
    SELECT f.id AS facility_id,
           COALESCE(SUM(EXTRACT(EPOCH FROM (bi.end_at - bi.start_at)) / 3600), 0) AS total_hours
    FROM facility_list f
    LEFT JOIN booking_instances bi ON bi.facility_id = f.id
      AND bi.start_at::date >= p_start_date
      AND bi.end_at::date <= p_end_date
      AND (bi.status IS NULL OR bi.status NOT IN ('cancelled'))
    GROUP BY f.id
  ),
  peak AS (
    SELECT EXTRACT(HOUR FROM bi.start_at AT TIME ZONE 'Asia/Aden')::INT AS hour24,
           COUNT(*)::INT AS booking_count
    FROM booking_instances bi
    JOIN bookings b ON b.id = bi.booking_id
    WHERE b.facility_group_id = p_facility_group_id
      AND bi.start_at::date >= p_start_date
      AND bi.end_at::date <= p_end_date
      AND (bi.status IS NULL OR bi.status NOT IN ('cancelled'))
    GROUP BY hour24
    ORDER BY hour24
  )
  SELECT jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'facilities', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object(
          'facility_id', fl.id,
          'facility_name', fl.name,
          'booked_hours', ROUND(b.total_hours::NUMERIC, 1),
          'available_hours', v_days * v_hours_per_day,
          'utilization_percent', CASE
            WHEN v_days * v_hours_per_day > 0
            THEN ROUND((b.total_hours / (v_days * v_hours_per_day) * 100)::NUMERIC, 1)
            ELSE 0 END
        ) ORDER BY fl.name) FROM facility_list fl LEFT JOIN booked b ON b.facility_id = fl.id),
        '[]'::jsonb
      ),
      'peak_hours', COALESCE(
        (SELECT jsonb_agg(jsonb_build_object(
          'hour', p.hour24,
          'booking_count', p.booking_count
        ) ORDER BY p.hour24) FROM peak p),
        '[]'::jsonb
      ),
      'summary', jsonb_build_object(
        'total_booked_hours', (SELECT COALESCE(SUM(total_hours), 0) FROM booked),
        'total_available_hours', (SELECT v_days * COUNT(*) * v_hours_per_day FROM facilities WHERE group_id = p_facility_group_id),
        'overall_utilization', ROUND((
          SELECT CASE
            WHEN v_days * COUNT(*) * v_hours_per_day > 0
            THEN (COALESCE(SUM(b.total_hours), 0) / (v_days * COUNT(*) * v_hours_per_day) * 100)::NUMERIC
            ELSE 0 END
          FROM booked b
        ), 1)
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_facility_analytics TO authenticated;

-- ============================================================
-- إلغاء موعد واحد من حجز متسلسل
-- ============================================================
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

GRANT EXECUTE ON FUNCTION cancel_booking_instance TO authenticated;
