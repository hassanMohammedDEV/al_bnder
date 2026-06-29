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
