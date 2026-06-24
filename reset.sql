-- حذف الجداول الموجودة (ترتيب عكسي للتبعيات)
DROP TABLE IF EXISTS otp_codes CASCADE;
DROP TABLE IF EXISTS booking_instances CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS wallet_transactions CASCADE;
DROP TABLE IF EXISTS wallets CASCADE;
DROP TABLE IF EXISTS advertisements CASCADE;
DROP TABLE IF EXISTS offers CASCADE;
DROP TABLE IF EXISTS facilities CASCADE;
DROP TABLE IF EXISTS facility_groups CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- حذف الـ triggers والـ functions
DROP TRIGGER IF EXISTS after_profile_insert ON profiles;
DROP TRIGGER IF EXISTS update_wallets_updated_at ON wallets;
DROP TRIGGER IF EXISTS update_bookings_updated_at ON bookings;
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;

DROP FUNCTION IF EXISTS create_wallets_for_new_user();
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP FUNCTION IF EXISTS auth.user_role();
DROP FUNCTION IF EXISTS auth.user_facility_group_id();
