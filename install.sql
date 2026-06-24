-- ============================================================
-- AL BNDR - FULL INSTALL (DROP + CREATE)
-- ============================================================

-- حذف كل شيء موجود
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

DROP FUNCTION IF EXISTS user_role();
DROP FUNCTION IF EXISTS user_facility_group_id();
DROP FUNCTION IF EXISTS create_wallets_for_new_user();
DROP FUNCTION IF EXISTS update_updated_at_column();

-- -------------------------------------------------------
-- 1. EXTENSION
-- -------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------
-- 2. TABLES
-- -------------------------------------------------------
CREATE TABLE facility_groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  logo_url    TEXT,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE facilities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  description     TEXT,
  location        TEXT,
  images          TEXT[],
  price_per_hour  DECIMAL(10,2) NOT NULL CHECK (price_per_hour > 0),
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone             TEXT UNIQUE NOT NULL,
  full_name         TEXT,
  role              TEXT NOT NULL DEFAULT 'user'
                      CHECK (role IN ('user', 'facility_admin', 'facility_viewer', 'super_admin')),
  facility_group_id UUID REFERENCES facility_groups(id) ON DELETE SET NULL,
  is_active         BOOLEAN DEFAULT true,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE wallets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  balance           DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, facility_group_id)
);

CREATE TABLE wallet_transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  amount          DECIMAL(10,2) NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'refund')),
  reference_type  TEXT CHECK (reference_type IN ('booking', 'admin_deposit', 'refund')),
  reference_id    UUID,
  description     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  facility_id         UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  total_price         DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  payment_status      TEXT NOT NULL DEFAULT 'unpaid'
                        CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  is_recurring        BOOLEAN DEFAULT false,
  recurring_rule      JSONB,
  recurring_group_id  UUID,
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE booking_instances (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  start_at    TIMESTAMPTZ NOT NULL,
  end_at      TIMESTAMPTZ NOT NULL,
  price       DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  qr_token    TEXT UNIQUE DEFAULT encode(gen_random_bytes(16), 'hex'),
  created_at  TIMESTAMPTZ DEFAULT now(),
  CHECK (end_at > start_at)
);

CREATE TABLE advertisements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  title             TEXT NOT NULL,
  description       TEXT,
  image_url         TEXT,
  link_url          TEXT,
  is_active         BOOLEAN DEFAULT true,
  starts_at         TIMESTAMPTZ,
  ends_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE offers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_group_id   UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  facility_id         UUID REFERENCES facilities(id) ON DELETE CASCADE,
  title               TEXT NOT NULL,
  description         TEXT,
  discount_percentage DECIMAL(5,2) CHECK (discount_percentage > 0 AND discount_percentage <= 100),
  discount_amount     DECIMAL(10,2) CHECK (discount_amount > 0),
  day_of_week         INT CHECK (day_of_week BETWEEN 0 AND 6),
  start_time          TIME,
  end_time            TIME,
  min_hours           INT DEFAULT 1 CHECK (min_hours > 0),
  is_active           BOOLEAN DEFAULT true,
  valid_from          DATE,
  valid_until         DATE,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE otp_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       TEXT NOT NULL,
  code        TEXT NOT NULL,
  purpose     TEXT NOT NULL DEFAULT 'registration'
                CHECK (purpose IN ('registration', 'login', 'password_reset')),
  is_used     BOOLEAN DEFAULT false,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  CHECK (expires_at > created_at)
);

-- -------------------------------------------------------
-- 3. INDEXES
-- -------------------------------------------------------
CREATE INDEX idx_bi_facility_status_time
  ON booking_instances(facility_id, status, start_at, end_at);

CREATE INDEX idx_bi_booking_id ON booking_instances(booking_id);
CREATE INDEX idx_wallets_user_group ON wallets(user_id, facility_group_id);
CREATE INDEX idx_wt_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_facility ON bookings(facility_id);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_otp_phone_active ON otp_codes(phone, is_used, expires_at);
CREATE INDEX idx_ads_group_active ON advertisements(facility_group_id, is_active) WHERE is_active = true;
CREATE INDEX idx_offers_group_active ON offers(facility_group_id, is_active) WHERE is_active = true;

-- -------------------------------------------------------
-- 4. ROW LEVEL SECURITY
-- -------------------------------------------------------
ALTER TABLE facility_groups      ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities           ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings             ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_instances    ENABLE ROW LEVEL SECURITY;
ALTER TABLE advertisements       ENABLE ROW LEVEL SECURITY;
ALTER TABLE offers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes            ENABLE ROW LEVEL SECURITY;

-- Helper functions
CREATE OR REPLACE FUNCTION user_role()
RETURNS TEXT
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT role FROM public.profiles WHERE id = auth.uid()),
    'anon'
  );
$$;

CREATE OR REPLACE FUNCTION user_facility_group_id()
RETURNS UUID
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT facility_group_id FROM public.profiles WHERE id = auth.uid();
$$;

-- PROFILES RLS
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "profiles_select_admin_group"
  ON profiles FOR SELECT
  USING (
    user_role() IN ('facility_admin', 'facility_viewer', 'super_admin')
  );

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- FACILITY GROUPS RLS
CREATE POLICY "facility_groups_select_all"
  ON facility_groups FOR SELECT
  USING (true);

CREATE POLICY "facility_groups_insert_admin"
  ON facility_groups FOR INSERT
  WITH CHECK (user_role() = 'super_admin');

CREATE POLICY "facility_groups_update_admin"
  ON facility_groups FOR UPDATE
  USING (user_role() = 'super_admin')
  WITH CHECK (user_role() = 'super_admin');

-- FACILITIES RLS
CREATE POLICY "facilities_select_active"
  ON facilities FOR SELECT
  USING (is_active = true OR user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "facilities_insert_admin"
  ON facilities FOR INSERT
  WITH CHECK (
    (user_role() = 'facility_admin' AND group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

CREATE POLICY "facilities_update_admin"
  ON facilities FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

-- WALLETS RLS
CREATE POLICY "wallets_select_own"
  ON wallets FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "wallets_select_admin_group"
  ON wallets FOR SELECT
  USING (
    user_role() = 'super_admin'
    OR (user_role() IN ('facility_admin', 'facility_viewer') AND facility_group_id = user_facility_group_id())
  );

CREATE POLICY "wallets_update_admin"
  ON wallets FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND facility_group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

-- WALLET TRANSACTIONS RLS
CREATE POLICY "wallet_transactions_select_own"
  ON wallet_transactions FOR SELECT
  USING (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );

CREATE POLICY "wallet_transactions_select_admin_group"
  ON wallet_transactions FOR SELECT
  USING (
    user_role() = 'super_admin'
    OR (user_role() IN ('facility_admin', 'facility_viewer') AND wallet_id IN (
      SELECT id FROM wallets WHERE facility_group_id = user_facility_group_id()
    ))
  );

CREATE POLICY "wallet_transactions_insert_admin"
  ON wallet_transactions FOR INSERT
  WITH CHECK (
    (user_role() = 'facility_admin' AND wallet_id IN (
      SELECT id FROM wallets WHERE facility_group_id = user_facility_group_id()
    ))
    OR user_role() = 'super_admin'
  );

-- BOOKINGS RLS
CREATE POLICY "bookings_select_own"
  ON bookings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "bookings_select_admin_group"
  ON bookings FOR SELECT
  USING (
    user_role() = 'super_admin'
    OR (user_role() IN ('facility_admin', 'facility_viewer') AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = user_facility_group_id()
    ))
  );

CREATE POLICY "bookings_insert_user"
  ON bookings FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND user_role() = 'user'
  );

CREATE POLICY "bookings_update_admin"
  ON bookings FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = user_facility_group_id()
    ))
    OR user_role() = 'super_admin'
  );

-- BOOKING INSTANCES RLS
CREATE POLICY "booking_instances_select_own"
  ON booking_instances FOR SELECT
  USING (
    booking_id IN (SELECT id FROM bookings WHERE user_id = auth.uid())
  );

CREATE POLICY "booking_instances_select_admin_group"
  ON booking_instances FOR SELECT
  USING (
    user_role() = 'super_admin'
    OR (user_role() IN ('facility_admin', 'facility_viewer') AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = user_facility_group_id()
    ))
  );

CREATE POLICY "booking_instances_insert_user"
  ON booking_instances FOR INSERT
  WITH CHECK (
    booking_id IN (SELECT id FROM bookings WHERE user_id = auth.uid())
  );

CREATE POLICY "booking_instances_update_admin"
  ON booking_instances FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = user_facility_group_id()
    ))
    OR user_role() = 'super_admin'
  );

-- ADVERTISEMENTS RLS
CREATE POLICY "advertisements_select_all"
  ON advertisements FOR SELECT
  USING (is_active = true OR user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "advertisements_insert_admin_group"
  ON advertisements FOR INSERT
  WITH CHECK (
    (user_role() = 'facility_admin' AND facility_group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

CREATE POLICY "advertisements_update_admin_group"
  ON advertisements FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND facility_group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

-- OFFERS RLS
CREATE POLICY "offers_select_all"
  ON offers FOR SELECT
  USING (is_active = true OR user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "offers_insert_admin_group"
  ON offers FOR INSERT
  WITH CHECK (
    (user_role() = 'facility_admin' AND facility_group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

CREATE POLICY "offers_update_admin_group"
  ON offers FOR UPDATE
  USING (
    (user_role() = 'facility_admin' AND facility_group_id = user_facility_group_id())
    OR user_role() = 'super_admin'
  );

-- OTP CODES RLS (no direct access)
CREATE POLICY "otp_codes_no_access"
  ON otp_codes FOR ALL
  USING (false);

-- -------------------------------------------------------
-- 5. TRIGGERS
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_wallets_for_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO wallets (user_id, facility_group_id, balance)
  SELECT NEW.id, id, 0 FROM facility_groups WHERE is_active = true;
  RETURN NEW;
END;
$$;

CREATE TRIGGER after_profile_insert
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.create_wallets_for_new_user();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_wallets_updated_at
  BEFORE UPDATE ON wallets
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
