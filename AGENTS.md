# Al Bandar (ملاعب البندر) — Agent Guide

## Context
- Arabic RTL booking app
- 4 shells: user, admin, super-admin, viewer
- Each role has its own shell (no `if role` conditions in screens)
- Recurring bookings per-instance cancel, cancel_booking_instance RPC
- Official admin pinned ads: is_official + pinned_at DB + create_official_player_ad RPC
- JWT/session in FlutterSecureStorage
- Minimum booking 60 min, pending does NOT block slots (display or conflict check)
- Delete account requires typing "حذف"

## Before coding
- Run `flutter analyze` to check for warnings/errors
- No new files unless explicitly requested; prefer editing existing code

## CRITICAL: Auth state sequence (DO NOT CHANGE)
- `updateProfile()` must NEVER set `needsPhoneVerification` — that flag is controlled solely by `setPhoneVerified()` / `setNeedsPhoneVerification()` during an active verification flow. DB `phone_verified` may be stale (proxy/RPC fails), so `updateProfile` reads it for `phoneVerified` field but MUST NOT derive `needsPhoneVerification` from it.
- **Registration**: `setPhoneVerifiedDb()` → `_fetchProfile()` → `setPhoneVerified(true)` ← `setPhoneVerified(true)` must be LAST to override anything `_fetchProfile` wrote from DB.
- **Login**: `setLoggedIn()` → `_fetchProfile()` → `setPhoneVerified(true)` ← same reason.
- **On boot**: always fetch profile if `isLoggedIn` (no `!isProfileLoaded` guard). Safe try-catch around `getProfile()` — if it throws (timeout/network), clear session silently.
- **No splash screen / `isInitializing`** — was removed. Caused stuck white screen with loading. App just renders the correct screen after auth check; brief redirect flicker is acceptable. DO NOT reintroduce.
- **OTP back button**: if `pendingRegistrationProvider` is non-null → `/register`, else → `/login`.
- `setPhoneVerifiedDb()` (RPC) may fail silently through proxy — local `setPhoneVerified(true)` ensures the user isn't stuck in verification loop.

## Architecture
- State: Riverpod (NotifierProvider, BaseState/ActionStore, FutureProvider)
- Network: ApiClient.post('rpc/...', body: {...}, parser: ...) with Result<T>
- Auth: authStateProvider gives userId, role, phone
- DB changes in run-once.sql (single deploy file for Supabase)
- Run `run-once.sql` in Supabase SQL Editor to deploy DB changes

## Shell routing
- `home_screen.dart` — thin wrapper: routes by role to the appropriate shell
- `user/screens/user_shell.dart` — HomeTab, MyBookings, Wallet, UserSettings
- `admin/screens/admin_shell.dart` — Dashboard, PendingBookings, Reports, AdminSettings
- `super_admin/screens/super_admin_shell.dart` — Settlement, PendingBookings, Reports, AdminSettings
- `shared/screens/viewer_shell.dart` — Reports, SimpleSettings
- Tab state preserved via IndexedStack in each shell (no StatefulShellRoute)

## Role screens (no `if role` conditions)
- `user/screens/user_settings_screen.dart` — user settings (no role badge, no admin section)
- `admin/screens/admin_settings_screen.dart` — admin settings (with role badge)
- `shared/screens/simple_settings_screen.dart` — viewer settings (minimal)
- `super_admin/screens/settlement_screen.dart` — developer settlement per group
- `reports_screen.dart` — no role conditions (backend handles auth for wallet/analytics)

## Relevant paths
- `run-once.sql` — all DB schema + RPCs (includes settlement tables/functions)
- `supabase-functions.sql` — mirror for reference
- `lib/features/player_ads/` — PlayerAd model, repo, provider, screens
- `lib/features/admin/` — admin screens + admin repo (used by admin + super_admin shells)
- `lib/features/super_admin/` — super_admin screens (settlement, shell)
- `lib/features/user/` — user screens (settings, shell)
- `lib/core/router/app_router.dart` — all routes
- `lib/features/auth/providers/auth_provider.dart` — authStateProvider

## Settlement feature
- `developer_settlements` table + `developer_settled` column on bookings
- `record_developer_settlement` RPC (super_admin only)
- `get_admin_dashboard` returns `developer_due` + `developer_due_count` per group
- Settlement screen in super_admin shell — lists groups with due amounts, "تصفير" button per group
- Admin dashboard still shows settlement card for super_admin (legacy, super_admin no longer uses it)
- `dashboardProvider` (FutureProvider) and `adminActionProvider` from admin feature are used by both admin and super_admin

## Relevant paths (cont.)
- `lib/features/announcements/providers/local_notification_provider.dart` — LocalNotification model + SharedPreferences-backed provider
- `lib/features/announcements/presentaion/screens/announcements_screen.dart` — merged server + local notifications display with divider

## Local notifications
- `LocalNotification` model + `localNotificationsProvider` (Riverpod NotifierProvider) backed by SharedPreferences
- Welcome notification added on OTP registration success (`otp_screen.dart`)
- Booking-created notification added on `BookingActionNotifier.createBooking` success (`booking_provider.dart`)
- Displayed in `announcements_screen.dart` below server announcements with a visual divider and "إشعارات التطبيق" header
- Swipe-to-dismiss (`Dismissible`) to remove local notifications

## In Progress
_none_

## Done

### Blank screen on reinstall (stale Keychain)
- Root cause: `AuthNotifier.build()` only re-fetched profile when `!initial.isProfileLoaded`, but Keychain persists `isProfileLoaded=true` across uninstall on iOS
- Fix: removed `!initial.isProfileLoaded` condition — always call `getProfile()` if `isLoggedIn`, regardless of `isProfileLoaded`
- If profile fetch fails (deleted user / expired token / stale session), `_clearSession()` runs and auth resets to empty → login screen renders properly
- On success, `updateProfile` always runs (removed `!initial.isProfileLoaded` guard) to ensure fresh data from server
- Also: removed `needsPhoneVerification` from `_saveSession` so it's never persisted
- In `main.dart`, always set `needsPhoneVerification: false` on initial load (ignore stale session value)
- In `updateProfile()`, must NOT set `needsPhoneVerification` (see CRITICAL section above)
- Splash screen experiment (`isInitializing`) was removed — caused stuck white screen. DO NOT reintroduce.

### logoutAndClear() + deleteAccount()
- Added `logoutAndClear()` — async variant of `logout()` that `await`s `_clearSession()`
- Updated `deleteAccount()` to use `logoutAndClear()` instead of `logout()`

### Role-based shell refactoring
- Extracted `user_shell.dart`, `admin_shell.dart`, `viewer_shell.dart` from `home_screen.dart`
- `home_screen.dart` now a thin 11-line wrapper that delegates to the right shell
- Split `settings_screen.dart` into `user_settings_screen.dart`, `admin_settings_screen.dart`, `simple_settings_screen.dart` — zero role conditions
- Removed role condition from `reports_screen.dart` (backend handles auth)
- Router `/settings` route dispatches by role
- Deleted old `settings_screen.dart`

### Super admin feature
- Created `super_admin/` feature with dedicated shell + settlement screen
- Settlement screen shows groups with developer due amounts + "تصفير" button per group
- Added `developer_settlements` table, `developer_settled` column, and `record_developer_settlement` RPC to `run-once.sql`
- Super admin shell tabs: Settlement, PendingBookings, Reports, Settings

## Next Steps
- Run `run-once.sql` in Supabase SQL Editor to deploy settlement tables/RPCs
- Test delete-account flow end-to-end to confirm session clears properly after account deletion