# Database Overview — ملاعب البندر

**Platform:** Supabase (PostgreSQL + PostgREST)  
**Auth:** Built-in Supabase Auth (phone-based OTP → JWT)  
**RLS:** Row-Level Security on all tables  
**Functions:** ~60 RPC functions (SECURITY DEFINER)

---

## Entity Relationship (Core)

```
facility_groups ──┬── facilities
                  ├── group_settings          (1:1)
                  ├── wallets                 (1:N per user)
                  ├── advertisements
                  ├── offers
                  ├── player_ads
                  └── developer_settlements

profiles ──┬── bookings ──┬── booking_instances
           ├── wallets     └── wallet_transactions
           ├── player_ads
           └── player_ad_bans

bookings ──┬── booking_instances
           └── wallet_transactions (reference)
```

---

## Tables

| Table | PK | Key Columns | Notes |
|-------|----|-------------|-------|
| `facility_groups` | `id UUID` | `name`, `phone`, `is_active` | A "مجموعة ملاعب" (e.g. البندر) |
| `facilities` | `id UUID` | `group_id → facility_groups`, `name`, `price_per_hour`, `is_active`, `sort_order` | Individual pitch/court |
| `profiles` | `id UUID → auth.users` | `phone (UNIQUE)`, `full_name`, `role` ('user'/'facility_admin'/'facility_viewer'/'super_admin'), `facility_group_id` | Auto-created via trigger on `auth.users` INSERT |
| `group_settings` | `facility_group_id UUID → facility_groups` | `opening_time`, `closing_time_{sun..sat}`, `deposit_amount`, `contract_expiry_hours`, `max_booking_hours`, `slot_fine_from`, `slot_fine_to` | 1:1 with facility_groups |
| `bookings` | `id UUID` | `user_id → profiles` (nullable), `facility_id → facilities`, `status`, `payment_status`, `total_price`, `paid_amount`, `is_admin_booking` | Status: pending → confirmed/cancelled/completed |
| `booking_instances` | `id UUID` | `booking_id → bookings`, `facility_id → facilities`, `start_at`, `end_at`, `price`, `status`, `qr_token (UNIQUE)` | Each booking has 1+ instances |
| `wallets` | `id UUID` | `user_id → profiles`, `facility_group_id → facility_groups`, `balance`, UNIQUE(user_id, group_id) | Per-group wallet |
| `wallet_transactions` | `id UUID` | `wallet_id → wallets`, `amount`, `type` (deposit/withdrawal/refund), `reference_type` | Audit log |
| `player_ads` | `id UUID` | `creator_id → auth.users`, `type` (looking_team/nakusna), `days`, `start/end_time`, `players_needed`, `status` | Player-to-player ads |
| `player_ad_reports` | `id UUID` | `ad_id → player_ads`, `reporter_id → auth.users`, `reason` | |
| `player_ad_bans` | `id UUID` | `user_id`, `facility_group_id`, UNIQUE(user_id, group_id) | |
| `advertisements` | `id UUID` | `facility_group_id`, `title`, `image_url`, `is_active`, `sort_order` | Facility ad banners |
| `announcements` | `id UUID` | `sender_id → auth.users`, `title`, `body` | |
| `announcement_reads` | (announcement_id, user_id) | `read_at` | Composite PK |
| `otp_codes` | `id UUID` | `phone`, `code`, `purpose`, `expires_at` | OTP for auth |
| `offers` | `id UUID` | `facility_group_id`, `discount_percentage/amount`, `day_of_week`, `valid_from/until` | Discount offers |
| `developer_settlements` | `id UUID` | `facility_group_id`, `amount`, `notes` | Super-admin settlements |

---

## Key RPC Functions

### Booking Flow
| Function | Caller | Purpose |
|----------|--------|---------|
| `create_booking` | user | Creates pending booking, validates hours/wallet/overlaps, handles recurring |
| `admin_create_booking` | admin | Creates booking on behalf of user/guest, optional auto-confirm |
| `admin_confirm_booking` | admin | Confirms pending/pending_approval booking, sets payment status |
| `cancel_booking` | user/admin | Cancels, processes partial refund (keeps deposit) |
| `admin_shrink_booking` | admin | Truncates booking end, recalculates price, refunds |
| `admin_reschedule_booking` | admin | Shifts booking to new time, checks availability |
| `get_available_slots` | anon/auth | Returns booked intervals per facility+date (excludes `pending`) |

### Wallet
| Function | Caller | Purpose |
|----------|--------|---------|
| `get_my_wallet` | user | Balance + transactions for a group |
| `admin_deposit_wallet` | admin | Deposit to user wallet, auto-create wallet |
| `admin_deduct_wallet` | admin | Deduct from user wallet (checks balance) |

### Admin
| Function | Caller | Purpose |
|----------|--------|---------|
| `get_admin_dashboard` | admin | Stats: bookings, revenue, deposits, developer_due |
| `admin_get_pending_bookings` | admin | Pending bookings list |
| `get_group_settings` / `upsert_group_settings` | admin | Read/write group configuration |
| `get_facility_analytics` | admin | Utilization %, peak hours, summary |
| `admin_get_booking_by_qr_token` | admin | QR code lookup |

### Player Ads
| Function | Caller | Purpose |
|----------|--------|---------|
| `get_player_ads` | anon/auth | Active ads for a group |
| `create_player_ad` | user | Post "looking_team" or "nakusna" ad |
| `report_player_ad` / `dismiss_report` | user/admin | Report/dismiss |
| `ban_user_from_player_ads` / `unban` | admin | Ban management |
| `auto_delete_expired_player_ads` | cron | Daily cleanup of past-date ads |

### Account
| Function | Caller | Purpose |
|----------|--------|---------|
| `delete_my_account` | user | Cascading delete: wallets → bookings → player_ads → reports → announcements → notifications → profile |
| `get_my_profile` | user | Current user profile |

---

## Auth Flow

```
Phone → generate_otp → SMS (dev: 000000) → verify_otp → login/register
                                                    ↓
                                            JWT issued by Supabase Auth
                                                    ↓
                                       All RPC calls → auth.uid() → profile check
```

- `auth.user_role()` / `auth.user_facility_group_id()` — helper functions
- Trigger `on_auth_user_created` auto-creates `profiles` row
- Trigger `after_profile_insert` auto-creates wallets for all active groups

---

## RLS Strategy

All tables have `ENABLE ROW LEVEL SECURITY.` Most RPC functions are `SECURITY DEFINER` (run as owner), bypassing RLS. Direct table access is restricted via policies:

| Pattern | Policy |
|---------|--------|
| **Users read own data** | `WHERE user_id = auth.uid()` |
| **Admins read group data** | `WHERE facility_group_id = user_facility_group_id() AND role IN ('facility_admin','super_admin')` |
| **Insert own** | `WHERE user_id = auth.uid()` |
| **Update by admin** | Role + group check |

---

## Cron Jobs

| Job | Schedule | Function |
|-----|----------|----------|
| `auto-cancel-pending-approval` | Every hour | `auto_cancel_expired_pending_approval()` |
| `auto-delete-expired-player-ads` | Daily 00:00 | `auto_delete_expired_player_ads()` |

---

## Trigger Functions

| Trigger | On | Fires | Action |
|---------|----|-------|--------|
| `on_auth_user_created` | `auth.users` | AFTER INSERT | Creates profile row |
| `after_profile_insert` | `profiles` | AFTER INSERT | Creates wallets for all active groups |
| `update_updated_at_column` | wallets, bookings, profiles | BEFORE UPDATE | Sets `updated_at = now()` |
| `trg_booking_instance_telegram` | `booking_instances` | AFTER INSERT | Sends Telegram notification |

<｜｜DSML｜｜parameter name="filePath" string="true">/Users/hassan/IdeaProjects/al_bndr/DATABASE.md