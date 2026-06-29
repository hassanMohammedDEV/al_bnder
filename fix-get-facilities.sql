-- ============================================================
-- AL BNDR - FIX get_facilities (remove missing columns)
-- شغّل هذا في Supabase SQL Editor
-- ============================================================

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
