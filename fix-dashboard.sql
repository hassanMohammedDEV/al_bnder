-- إضافة developer_due إلى لوحة التحكم
-- شغّل هذا في Supabase SQL Editor

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
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit'),
      'developer_due', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'confirmed'),
      'today_confirmed', (SELECT COUNT(*) FROM bookings b
                          JOIN facilities f ON b.facility_id = f.id
                          WHERE f.group_id = fg.id AND b.status = 'confirmed'
                            AND b.created_at >= CURRENT_DATE),
      'today_pending', (SELECT COUNT(*) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'pending'
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
      'total_revenue', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.payment_status = 'paid'),
      'total_deposits', (SELECT COALESCE(SUM(wt.amount), 0) FROM wallet_transactions wt
                         JOIN wallets w ON wt.wallet_id = w.id
                         WHERE w.facility_group_id = fg.id AND wt.type = 'deposit'),
      'developer_due', (SELECT COALESCE(SUM(b.total_price), 0) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'confirmed'),
      'today_confirmed', (SELECT COUNT(*) FROM bookings b
                          JOIN facilities f ON b.facility_id = f.id
                          WHERE f.group_id = fg.id AND b.status = 'confirmed'
                            AND b.created_at >= CURRENT_DATE),
      'today_pending', (SELECT COUNT(*) FROM bookings b
                        JOIN facilities f ON b.facility_id = f.id
                        WHERE f.group_id = fg.id AND b.status = 'pending'
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

GRANT EXECUTE ON FUNCTION get_admin_dashboard TO authenticated;
