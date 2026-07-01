-- ============================================================
-- AL BNDR - PLAYER ADS FUNCTIONS
-- Response format: { success, message, data }
-- Run this file in Supabase SQL Editor
-- ============================================================

-- -------------------------------------------------------
-- TABLES (run these first if tables don't exist)
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS player_ads (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  creator_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creator_name      TEXT NOT NULL DEFAULT '',
  creator_phone     TEXT NOT NULL DEFAULT '',
  type              TEXT NOT NULL CHECK (type IN ('looking_team', 'nakusna')),
  days              TEXT[] DEFAULT '{}',
  start_time        TEXT,
  end_time          TEXT,
  facility_id       UUID REFERENCES facilities(id) ON DELETE SET NULL,
  facility_name     TEXT,
  date              TEXT,
  players_needed    INT,
  position          TEXT,
  notes             TEXT,
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS player_ad_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id        UUID NOT NULL REFERENCES player_ads(id) ON DELETE CASCADE,
  reporter_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason       TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_player_ads_group ON player_ads(facility_group_id);
CREATE INDEX IF NOT EXISTS idx_player_ads_creator ON player_ads(creator_id);
CREATE INDEX IF NOT EXISTS idx_player_ads_status ON player_ads(status);
CREATE INDEX IF NOT EXISTS idx_player_ad_reports_ad ON player_ad_reports(ad_id);

-- -------------------------------------------------------
-- 1. GET PLAYER ADS
-- POST /rest/v1/rpc/get_player_ads
-- Body: { "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
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
    'created_at', pa.created_at
  ) ORDER BY pa.created_at DESC) INTO v_ads
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


-- -------------------------------------------------------
-- 2. CREATE PLAYER AD
-- POST /rest/v1/rpc/create_player_ad
-- Body: { "p_facility_group_id": "uuid", "p_type": "text",
--         "p_days": "text[]", "p_start_time": "text",
--         "p_end_time": "text", ... }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION create_player_ad(
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
  v_user_id UUID;
  v_user_name TEXT;
  v_user_phone TEXT;
  v_ad_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT full_name, phone INTO v_user_name, v_user_phone
  FROM profiles WHERE id = v_user_id;

  v_ad_id := gen_random_uuid();

  INSERT INTO player_ads (
    id, facility_group_id, creator_id, creator_name, creator_phone,
    type, days, start_time, end_time, facility_id, facility_name,
    date, players_needed, position, notes, status, created_at
  ) VALUES (
    v_ad_id, p_facility_group_id, v_user_id, COALESCE(v_user_name, ''),
    COALESCE(v_user_phone, ''),
    p_type, COALESCE(p_days, '{}'), p_start_time, p_end_time,
    p_facility_id, p_facility_name, p_date, p_players_needed,
    p_position, p_notes, 'active', NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم نشر الإعلان',
    'data', jsonb_build_object('id', v_ad_id)
  );
END;
$$;


-- -------------------------------------------------------
-- 3. DELETE PLAYER AD
-- POST /rest/v1/rpc/delete_player_ad
-- Body: { "p_ad_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_player_ad(
  p_ad_id UUID
)
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
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  DELETE FROM player_ads
  WHERE id = p_ad_id
    AND (creator_id = v_user_id OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = v_user_id AND role IN ('facility_admin', 'super_admin')
    ));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح أو الإعلان غير موجود', 'data', null);
  END IF;

  -- Also delete any reports for this ad
  DELETE FROM player_ad_reports WHERE ad_id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم الحذف', 'data', null);
END;
$$;


-- -------------------------------------------------------
-- 4. REPORT PLAYER AD
-- POST /rest/v1/rpc/report_player_ad
-- Body: { "p_ad_id": "uuid", "p_reason": "text" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION report_player_ad(
  p_ad_id  UUID,
  p_reason TEXT
)
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
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  INSERT INTO player_ad_reports (id, ad_id, reporter_id, reason, created_at)
  VALUES (gen_random_uuid(), p_ad_id, v_user_id, p_reason, NOW());

  RETURN jsonb_build_object('success', true, 'message', 'تم الإبلاغ', 'data', null);
END;
$$;


-- -------------------------------------------------------
-- 5. GET REPORTED PLAYER ADS
-- POST /rest/v1/rpc/get_reported_player_ads
-- Body: { "p_facility_group_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_reported_player_ads(
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_is_admin BOOLEAN;
  v_ads JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_user_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

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
    'created_at', pa.created_at
  ) ORDER BY pa.created_at DESC) INTO v_ads
  FROM player_ads pa
  LEFT JOIN profiles u ON u.id = pa.creator_id
  WHERE pa.facility_group_id = p_facility_group_id
    AND EXISTS (SELECT 1 FROM player_ad_reports r WHERE r.ad_id = pa.id);

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


-- -------------------------------------------------------
-- 6. DISMISS PLAYER AD REPORT
-- POST /rest/v1/rpc/dismiss_player_ad_report
-- Body: { "p_ad_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION dismiss_player_ad_report(
  p_ad_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_user_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  DELETE FROM player_ad_reports WHERE ad_id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم التجاهل', 'data', null);
END;
$$;

-- -------------------------------------------------------
-- 7. UPDATE PLAYER AD
-- POST /rest/v1/rpc/update_player_ad
-- Body: { "p_ad_id": "uuid", "p_players_needed": int, ... }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION update_player_ad(
  p_ad_id           UUID,
  p_players_needed  INT DEFAULT NULL,
  p_notes           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_creator UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT creator_id INTO v_creator FROM player_ads WHERE id = p_ad_id;
  IF v_creator IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'الإعلان غير موجود', 'data', null);
  END IF;
  IF v_creator <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'ليس لديك صلاحية', 'data', null);
  END IF;

  UPDATE player_ads SET
    players_needed = COALESCE(p_players_needed, players_needed),
    notes = COALESCE(p_notes, notes)
  WHERE id = p_ad_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم التعديل', 'data', null);
END;
$$;

-- -------------------------------------------------------
-- 8. BAN USER FROM PLAYER ADS
-- POST /rest/v1/rpc/ban_user_from_player_ads
-- Body: { "p_user_id": "uuid", "p_reason": "text" }
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_ad_bans (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  banned_by         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason            TEXT DEFAULT '',
  created_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, facility_group_id)
);

CREATE OR REPLACE FUNCTION ban_user_from_player_ads(
  p_user_id           UUID,
  p_facility_group_id UUID,
  p_reason            TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_admin_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  INSERT INTO player_ad_bans (user_id, facility_group_id, banned_by, reason, created_at)
  VALUES (p_user_id, p_facility_group_id, v_admin_id, p_reason, NOW())
  ON CONFLICT (user_id, facility_group_id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'message', 'تم الحظر', 'data', null);
END;
$$;

-- -------------------------------------------------------
-- 9. UNBAN USER
-- POST /rest/v1/rpc/unban_user_from_player_ads
-- Body: { "p_user_id": "uuid" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION unban_user_from_player_ads(
  p_user_id           UUID,
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_admin_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  DELETE FROM player_ad_bans
  WHERE user_id = p_user_id AND facility_group_id = p_facility_group_id;

  RETURN jsonb_build_object('success', true, 'message', 'تم إلغاء الحظر', 'data', null);
END;
$$;

-- -------------------------------------------------------
-- 10. GET BANNED USERS (with optional phone search)
-- POST /rest/v1/rpc/get_banned_users
-- Body: { "p_facility_group_id": "uuid", "p_search": "text" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_banned_users(
  p_facility_group_id UUID,
  p_search            TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_is_admin BOOLEAN;
  v_users JSONB;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_admin_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'user_id', b.user_id,
    'full_name', COALESCE(p.full_name, ''),
    'phone', p.phone,
    'reason', b.reason,
    'banned_by', b.banned_by,
    'created_at', b.created_at
  ) ORDER BY b.created_at DESC) INTO v_users
  FROM player_ad_bans b
  JOIN profiles p ON p.id = b.user_id
  WHERE b.facility_group_id = p_facility_group_id
    AND (p_search = '' OR p.phone ILIKE '%' || p_search || '%' OR p.full_name ILIKE '%' || p_search || '%');

  IF v_users IS NULL THEN
    v_users := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'success', 'data', v_users);
END;
$$;

-- -------------------------------------------------------
-- 11. SEARCH USERS TO BAN
-- POST /rest/v1/rpc/search_users_to_ban
-- Body: { "p_facility_group_id": "uuid", "p_search": "text" }
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION search_users_to_ban(
  p_facility_group_id UUID,
  p_search            TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_is_admin BOOLEAN;
  v_users JSONB;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_admin_id AND role IN ('facility_admin', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'user_id', p.id,
    'full_name', COALESCE(p.full_name, ''),
    'phone', p.phone,
    'is_banned', CASE WHEN b.id IS NOT NULL THEN true ELSE false END
  ) ORDER BY p.created_at DESC) INTO v_users
  FROM profiles p
  LEFT JOIN player_ad_bans b ON b.user_id = p.id AND b.facility_group_id = p_facility_group_id
  WHERE p.phone ILIKE '%' || p_search || '%'
     OR p.full_name ILIKE '%' || p_search || '%'
  LIMIT 20;

  IF v_users IS NULL THEN
    v_users := '[]'::JSONB;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'success', 'data', v_users);
END;
$$;

-- -------------------------------------------------------
-- 12. CHECK IF USER IS BANNED (used by create_player_ad)
-- -------------------------------------------------------
DROP FUNCTION IF EXISTS check_player_ad_banned;
CREATE OR REPLACE FUNCTION check_player_ad_banned(
  p_facility_group_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_banned BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'غير مصرح', 'data', null);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM player_ad_bans
    WHERE user_id = v_user_id AND facility_group_id = p_facility_group_id
  ) INTO v_banned;

  RETURN jsonb_build_object('success', true, 'message', 'success', 'data', v_banned);
END;
$$;

GRANT EXECUTE ON FUNCTION get_player_ads TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_player_ad TO authenticated;
GRANT EXECUTE ON FUNCTION delete_player_ad TO authenticated;
GRANT EXECUTE ON FUNCTION update_player_ad TO authenticated;
GRANT EXECUTE ON FUNCTION report_player_ad TO authenticated;
GRANT EXECUTE ON FUNCTION get_reported_player_ads TO authenticated;
GRANT EXECUTE ON FUNCTION dismiss_player_ad_report TO authenticated;
GRANT EXECUTE ON FUNCTION ban_user_from_player_ads TO authenticated;
GRANT EXECUTE ON FUNCTION unban_user_from_player_ads TO authenticated;
GRANT EXECUTE ON FUNCTION get_banned_users TO authenticated;
GRANT EXECUTE ON FUNCTION search_users_to_ban TO authenticated;
GRANT EXECUTE ON FUNCTION check_player_ad_banned TO authenticated;

-- -------------------------------------------------------
-- 13. AUTO DELETE EXPIRED PLAYER ADS
-- POST /rest/v1/rpc/auto_delete_expired_player_ads
-- Body: {}
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_delete_expired_player_ads()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM player_ads
  WHERE status = 'active'
    AND date IS NOT NULL
    AND date::DATE < CURRENT_DATE;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حذف ' || v_count || ' إعلان منتهي',
    'data', jsonb_build_object('deleted_count', v_count)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION auto_delete_expired_player_ads TO authenticated;

-- -------------------------------------------------------
-- Schedule auto-delete via pg_cron (runs daily at midnight)
-- Idempotent: unschedules first, then schedules
-- -------------------------------------------------------
DO $cron$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule('auto-delete-expired-player-ads');
  PERFORM cron.schedule(
    'auto-delete-expired-player-ads',
    '0 0 * * *',
    $cron_task$SELECT auto_delete_expired_player_ads()$cron_task$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, auto-delete scheduling skipped. Run manually: SELECT auto_delete_expired_player_ads();';
END;
$cron$;
