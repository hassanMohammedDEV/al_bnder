# Al Bandar (ملاعب البندر) — Agent Guide

## Context
- Arabic RTL booking app
- 3 shells: user, admin, super-admin
- Recurring bookings per-instance cancel, cancel_booking_instance RPC
- Official admin pinned ads: is_official + pinned_at DB + create_official_player_ad RPC
- JWT/session in FlutterSecureStorage
- Minimum booking 60 min, pending does NOT block slots
- Delete account requires typing "حذف"

## Before coding
- Run `flutter analyze` to check for warnings/errors
- No new files unless explicitly requested; prefer editing existing code

## Architecture
- State: Riverpod (NotifierProvider, BaseState/ActionStore)
- Network: ApiClient.post('rpc/...', body: {...}, parser: ...) with Result<T>
- Auth: authStateProvider gives userId, role, phone
- DB changes in run-once.sql (single deploy file for Supabase)
- Run `run-once.sql` in Supabase SQL Editor to deploy DB changes

## Relevant paths
- `run-once.sql` — all DB schema + RPCs
- `supabase-functions.sql` — mirror for reference
- `lib/features/player_ads/` — PlayerAd model, repo, provider, screens
- `lib/features/admin/` — admin screens + admin repo
- `lib/core/router/app_router.dart` — all routes
- `lib/features/auth/providers/auth_provider.dart` — authStateProvider

## In Progress
_none_

## Done

### OTP fresh-install redirect loop
- Remove `needsPhoneVerification` from persisted session (`_saveSession` in auth_provider.dart)
- In `main.dart`, always set `needsPhoneVerification: false` on initial load
- In `AuthNotifier.build()`, if initial auth exists with `isLoggedIn=true` and `isProfileLoaded=false`, schedule a `Future.microtask` to call `getProfile()`
- In `updateProfile()`, if `phone_verified` is false, auto-set `needsPhoneVerification=true`
- On fresh install with stale Keychain data: profile fetch fails → `profileLoadFailed()` → no OTP redirect → login screen

### logoutAndClear() + deleteAccount()
- Added `logoutAndClear()` — async variant of `logout()` that `await`s `_clearSession()`
- Updated `deleteAccount()` to use `logoutAndClear()` instead of `logout()`

## Next Steps
- Monitor for any regressions in OTP flow on fresh install vs. upgrade scenarios
- Test delete-account flow end-to-end to confirm session clears properly after account deletion
