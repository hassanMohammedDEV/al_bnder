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
