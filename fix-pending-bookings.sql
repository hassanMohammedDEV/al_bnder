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
    'user_name', p.full_name,
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

  RETURN jsonb_build_object('success', true, 'message', null, 'data', jsonb_build_object('bookings', v_bookings));
END;
$$;

-- Grant execute
GRANT EXECUTE ON FUNCTION admin_get_pending_bookings TO authenticated;
