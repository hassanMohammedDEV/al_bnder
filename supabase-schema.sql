-- ============================================================
-- AL BNDR - SUPABASE DATABASE SCHEMA
-- Phase 1: Tables, Indexes, RLS Policies
-- ============================================================

-- ----------------------------
-- 1. EXTENSIONS
-- ----------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------
-- 2. TABLES
-- ----------------------------

-- 2.1 Facility Groups
CREATE TABLE facility_groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  logo_url    TEXT,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 2.2 Facilities (playgrounds/fields)
CREATE TABLE facilities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  description     TEXT,
  location        TEXT,
  images          TEXT[],
  price_per_hour  DECIMAL(10,2) NOT NULL CHECK (price_per_hour > 0),
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- 2.3 User Profiles (extends auth.users)
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

-- 2.4 Wallets (per user per facility group)
CREATE TABLE wallets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  balance           DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, facility_group_id)
);

-- 2.5 Wallet Transactions
CREATE TABLE wallet_transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  amount          DECIMAL(10,2) NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'refund')),
  reference_type  TEXT CHECK (reference_type IN ('booking', 'admin_deposit', 'refund', 'admin_deduct')),
  reference_id    UUID,
  description     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- 2.6 Bookings (master record)
CREATE TABLE bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID REFERENCES profiles(id) ON DELETE CASCADE,
  guest_name          TEXT,
  facility_id         UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  total_price         DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  payment_status      TEXT NOT NULL DEFAULT 'unpaid'
                        CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  is_recurring        BOOLEAN DEFAULT false,
  recurring_rule      JSONB,
  recurring_group_id  UUID,
  guest_phone         TEXT,
  notes               TEXT,
  approval_deadline   TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now(),
  paid_amount         DECIMAL(10,2) DEFAULT 0
);

-- 2.7 Booking Instances (individual time slots)
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

-- 2.8 Advertisements
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

-- 2.9 Offers / Promotions
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

-- 2.10 OTP Codes
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

-- 2.11 Developer Settlements
CREATE TABLE developer_settlements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_group_id UUID NOT NULL REFERENCES facility_groups(id) ON DELETE CASCADE,
  amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  created_by      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE
);


-- 2.12 Group Settings
CREATE TABLE group_settings (
  facility_group_id  UUID PRIMARY KEY REFERENCES facility_groups(id) ON DELETE CASCADE,
  opening_time       TIME NOT NULL DEFAULT '16:00',
  closing_time_sun   TIME NOT NULL DEFAULT '22:00',
  closing_time_mon   TIME NOT NULL DEFAULT '22:00',
  closing_time_tue   TIME NOT NULL DEFAULT '22:00',
  closing_time_wed   TIME NOT NULL DEFAULT '22:00',
  closing_time_thu   TIME NOT NULL DEFAULT '22:00',
  closing_time_fri   TIME NOT NULL DEFAULT '22:00',
  closing_time_sat   TIME NOT NULL DEFAULT '22:00',
  deposit_amount     DECIMAL(10,2) NOT NULL DEFAULT 5000,
  contract_expiry_hours INT NOT NULL DEFAULT 8,
  updated_at         TIMESTAMPTZ DEFAULT now(),
  updated_by         UUID REFERENCES profiles(id) ON DELETE SET NULL
);


-- ----------------------------
-- 3. INDEXES
-- ----------------------------

-- Availability checks: find non-cancelled instances for a facility in a time range
CREATE INDEX idx_bi_facility_status_time
  ON booking_instances(facility_id, status, start_at, end_at);

-- Fast lookup of instances by booking
CREATE INDEX idx_bi_booking_id ON booking_instances(booking_id);

-- Wallet lookups by user
CREATE INDEX idx_wallets_user_group ON wallets(user_id, facility_group_id);

-- Wallet transactions by wallet
CREATE INDEX idx_wt_wallet_id ON wallet_transactions(wallet_id);

-- Bookings by user
CREATE INDEX idx_bookings_user ON bookings(user_id);

-- Bookings by facility
CREATE INDEX idx_bookings_facility ON bookings(facility_id);

-- Profiles lookup by role
CREATE INDEX idx_profiles_role ON profiles(role);

-- OTP lookup by phone (non-used, non-expired)
CREATE INDEX idx_otp_phone_active ON otp_codes(phone, is_used, expires_at);

-- Advertisements by group + active
CREATE INDEX idx_ads_group_active ON advertisements(facility_group_id, is_active) WHERE is_active = true;

-- Offers by group + active
CREATE INDEX idx_offers_group_active ON offers(facility_group_id, is_active) WHERE is_active = true;


-- ----------------------------
-- 4. ROW LEVEL SECURITY
-- ----------------------------

-- Enable RLS on all tables
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

-- -------------------------------------------------------
-- Helper function to get current user's role
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.user_role()
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

-- -------------------------------------------------------
-- Helper function to get current user's facility_group_id
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.user_facility_group_id()
RETURNS UUID
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT facility_group_id FROM public.profiles WHERE id = auth.uid();
$$;

-- ==============================================================
-- 4.1 PROFILES
-- ==============================================================
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "profiles_select_admin_group"
  ON profiles FOR SELECT
  USING (
    auth.user_role() IN ('facility_admin', 'facility_viewer', 'super_admin')
  );

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ==============================================================
-- 4.2 FACILITY GROUPS
-- ==============================================================
CREATE POLICY "facility_groups_select_all"
  ON facility_groups FOR SELECT
  USING (true);

CREATE POLICY "facility_groups_insert_admin"
  ON facility_groups FOR INSERT
  WITH CHECK (auth.user_role() = 'super_admin');

CREATE POLICY "facility_groups_update_admin"
  ON facility_groups FOR UPDATE
  USING (auth.user_role() = 'super_admin')
  WITH CHECK (auth.user_role() = 'super_admin');

-- ==============================================================
-- 4.3 FACILITIES
-- ==============================================================
CREATE POLICY "facilities_select_active"
  ON facilities FOR SELECT
  USING (is_active = true OR auth.user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "facilities_insert_admin"
  ON facilities FOR INSERT
  WITH CHECK (
    (auth.user_role() = 'facility_admin' AND group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

CREATE POLICY "facilities_update_admin"
  ON facilities FOR UPDATE
  USING (
    (auth.user_role() = 'facility_admin' AND group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.4 WALLETS
-- ==============================================================
CREATE POLICY "wallets_select_own"
  ON wallets FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "wallets_select_admin_group"
  ON wallets FOR SELECT
  USING (
    auth.user_role() = 'super_admin'
    OR
    (auth.user_role() IN ('facility_admin', 'facility_viewer') AND facility_group_id = auth.user_facility_group_id())
  );

CREATE POLICY "wallets_update_admin"
  ON wallets FOR UPDATE
  USING (
    (auth.user_role() = 'facility_admin' AND facility_group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.5 WALLET TRANSACTIONS
-- ==============================================================
CREATE POLICY "wallet_transactions_select_own"
  ON wallet_transactions FOR SELECT
  USING (
    wallet_id IN (
      SELECT id FROM wallets WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "wallet_transactions_select_admin_group"
  ON wallet_transactions FOR SELECT
  USING (
    auth.user_role() = 'super_admin'
    OR
    (auth.user_role() IN ('facility_admin', 'facility_viewer') AND wallet_id IN (
      SELECT id FROM wallets WHERE facility_group_id = auth.user_facility_group_id()
    ))
  );

CREATE POLICY "wallet_transactions_insert_admin"
  ON wallet_transactions FOR INSERT
  WITH CHECK (
    (auth.user_role() = 'facility_admin' AND wallet_id IN (
      SELECT id FROM wallets WHERE facility_group_id = auth.user_facility_group_id()
    ))
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.6 BOOKINGS
-- ==============================================================
CREATE POLICY "bookings_select_own"
  ON bookings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "bookings_select_admin_group"
  ON bookings FOR SELECT
  USING (
    auth.user_role() = 'super_admin'
    OR
    (auth.user_role() IN ('facility_admin', 'facility_viewer') AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = auth.user_facility_group_id()
    ))
  );

CREATE POLICY "bookings_insert_user"
  ON bookings FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND auth.user_role() = 'user'
  );

CREATE POLICY "bookings_update_admin"
  ON bookings FOR UPDATE
  USING (
    (auth.user_role() = 'facility_admin' AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = auth.user_facility_group_id()
    ))
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.7 BOOKING INSTANCES
-- ==============================================================
CREATE POLICY "booking_instances_select_own"
  ON booking_instances FOR SELECT
  USING (
    booking_id IN (SELECT id FROM bookings WHERE user_id = auth.uid())
  );

CREATE POLICY "booking_instances_select_admin_group"
  ON booking_instances FOR SELECT
  USING (
    auth.user_role() = 'super_admin'
    OR
    (auth.user_role() IN ('facility_admin', 'facility_viewer') AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = auth.user_facility_group_id()
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
    (auth.user_role() = 'facility_admin' AND facility_id IN (
      SELECT id FROM facilities WHERE group_id = auth.user_facility_group_id()
    ))
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.8 ADVERTISEMENTS
-- ==============================================================
CREATE POLICY "advertisements_select_all"
  ON advertisements FOR SELECT
  USING (is_active = true OR auth.user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "advertisements_insert_admin_group"
  ON advertisements FOR INSERT
  WITH CHECK (
    (auth.user_role() = 'facility_admin' AND facility_group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

CREATE POLICY "advertisements_update_admin_group"
  ON advertisements FOR UPDATE
  USING (
    (auth.user_role() = 'facility_admin' AND facility_group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.9 OFFERS
-- ==============================================================
CREATE POLICY "offers_select_all"
  ON offers FOR SELECT
  USING (is_active = true OR auth.user_role() IN ('facility_admin', 'facility_viewer', 'super_admin'));

CREATE POLICY "offers_insert_admin_group"
  ON offers FOR INSERT
  WITH CHECK (
    (auth.user_role() = 'facility_admin' AND facility_group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

CREATE POLICY "offers_update_admin_group"
  ON offers FOR UPDATE
  USING (
    (auth.user_role() = 'facility_admin' AND facility_group_id = auth.user_facility_group_id())
    OR
    auth.user_role() = 'super_admin'
  );

-- ==============================================================
-- 4.10 OTP CODES (only accessible via functions)
-- ==============================================================
CREATE POLICY "otp_codes_no_access"
  ON otp_codes FOR ALL
  USING (false);


-- ----------------------------
-- 4.11 GROUP SETTINGS
-- ----------------------------
ALTER TABLE group_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "group_settings_select_admin"
  ON group_settings FOR SELECT
  USING (
    user_role() IN ('facility_admin', 'facility_viewer', 'super_admin')
    AND (
      user_role() = 'super_admin'
      OR facility_group_id = auth.user_facility_group_id()
    )
  );

CREATE POLICY "group_settings_insert_admin"
  ON group_settings FOR INSERT
  WITH CHECK (
    user_role() IN ('facility_admin', 'super_admin')
    AND (
      user_role() = 'super_admin'
      OR facility_group_id = auth.user_facility_group_id()
    )
  );

CREATE POLICY "group_settings_update_admin"
  ON group_settings FOR UPDATE
  USING (
    user_role() IN ('facility_admin', 'super_admin')
    AND (
      user_role() = 'super_admin'
      OR facility_group_id = auth.user_facility_group_id()
    )
  );

CREATE POLICY "group_settings_delete_admin"
  ON group_settings FOR DELETE
  USING (
    user_role() IN ('facility_admin', 'super_admin')
    AND (
      user_role() = 'super_admin'
      OR facility_group_id = auth.user_facility_group_id()
    )
  );


-- ----------------------------
-- 5. TRIGGER: auto-create wallet on profile creation
-- ----------------------------
CREATE OR REPLACE FUNCTION create_wallets_for_new_user()
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
  EXECUTE FUNCTION create_wallets_for_new_user();

-- ----------------------------
-- 6. TRIGGER: update wallet.updated_at
-- ----------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
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
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
