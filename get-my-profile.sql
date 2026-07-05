-- ============================================================
-- AL BNDR - GET MY PROFILE
-- شغّل هذا في Supabase SQL Editor
-- ============================================================

CREATE OR REPLACE FUNCTION get_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_profile profiles%ROWTYPE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يرجى تسجيل الدخول أولاً', 'data', null);
  END IF;

  SELECT * INTO v_profile FROM profiles WHERE id = v_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المستخدم غير موجود', 'data', null);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم جلب البيانات بنجاح',
    'data', jsonb_build_object(
      'id', v_profile.id,
      'phone', v_profile.phone,
      'full_name', v_profile.full_name,
      'role', v_profile.role,
      'facility_group_id', v_profile.facility_group_id,
      'is_active', v_profile.is_active,
      'phone_verified', v_profile.phone_verified
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_profile TO authenticated;

-- التحقق:
-- SELECT * FROM get_my_profile();
