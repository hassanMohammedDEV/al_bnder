-- حذف حساب مستخدم عن طريق رقم الجوال
-- غير الرقم تحت وشغّل في SQL Editor

DO $$
DECLARE
  v_user_id UUID;
  p_phone TEXT := '730845718'; -- ← غيّر الرقم (بدون كود دولة)
BEGIN
  SELECT id INTO v_user_id FROM profiles WHERE phone = p_phone;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'ما لقيت مستخدم بهذا الرقم: %', p_phone;
  END IF;

  RAISE NOTICE 'بحذف المستخدم: %', v_user_id;

  DELETE FROM wallets WHERE user_id = v_user_id;
  DELETE FROM bookings WHERE user_id = v_user_id;
  DELETE FROM player_ads WHERE creator_id = v_user_id;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'announcement_reads') THEN
    DELETE FROM announcement_reads WHERE user_id = v_user_id;
  END IF;
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'announcements') THEN
    DELETE FROM announcements WHERE sender_id = v_user_id;
  END IF;
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
    DELETE FROM notifications WHERE user_id = v_user_id;
  END IF;

  DELETE FROM profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE '✅ تم حذف الحساب';
END;
$$;
