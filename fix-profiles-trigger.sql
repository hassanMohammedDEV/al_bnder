-- ============================================================
-- AL BNDR - AUTO-CREATE PROFILES ON SIGNUP
-- شغّل هذا في Supabase SQL Editor
-- ============================================================

-- ----------------------------------------
-- 1. إنشاء trigger function
--    تنشئ سجل في profiles بعد تسجيل مستخدم جديد
-- ----------------------------------------
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, full_name)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'phone',
      SPLIT_PART(NEW.email, '@', 1)
    ),
    COALESCE(NEW.raw_user_meta_data->>'name', '')
  );
  RETURN NEW;
END;
$$;

-- ----------------------------------------
-- 2. إنشاء trigger على auth.users
-- ----------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_profile_for_new_user();

-- ----------------------------------------
-- 3. إعادة إنشاء profiles للمستخدمين الحاليين
--    (اللي سجلوا قبل ما نضيف الـ trigger)
-- ----------------------------------------
INSERT INTO public.profiles (id, phone, full_name)
SELECT
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'phone',
    SPLIT_PART(au.email, '@', 1)
  ),
  COALESCE(au.raw_user_meta_data->>'name', '')
FROM auth.users au
LEFT JOIN public.profiles p ON p.id = au.id
WHERE p.id IS NULL;

-- ----------------------------------------
-- 4. التحقق
-- ----------------------------------------
-- SELECT * FROM profiles;
-- SELECT id, email, raw_user_meta_data FROM auth.users;
