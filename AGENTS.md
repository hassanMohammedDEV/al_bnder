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
