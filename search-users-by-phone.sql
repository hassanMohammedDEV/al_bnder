DROP FUNCTION IF EXISTS search_users_by_phone(TEXT);
DROP FUNCTION IF EXISTS search_users_by_phone(TEXT, UUID);

CREATE OR REPLACE FUNCTION search_users_by_phone(
  p_phone_query TEXT,
  p_facility_group_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin_role TEXT;
  v_users JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT role INTO v_admin_role
  FROM profiles WHERE id = v_admin_id;

  IF v_admin_role NOT IN ('facility_admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', p.id,
    'phone', p.phone,
    'full_name', p.full_name,
    'role', p.role
  ) ORDER BY p.created_at DESC) INTO v_users
  FROM profiles p
  WHERE p.phone ILIKE '%' || p_phone_query || '%'
    AND p.is_active = true
    AND p.role = 'user'
  LIMIT 20;

  IF v_users IS NULL THEN
    v_users := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object('users', v_users)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION search_users_by_phone(TEXT, UUID) TO authenticated;
