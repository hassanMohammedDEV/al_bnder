# Code Architecture — ملاعب البندر

**Framework:** Flutter (Material 3, RTL/Arabic)  
**State:** Riverpod (flutter_riverpod + app_platform_state)  
**Routing:** go_router (CupertinoPage transitions)  
**Network:** Supabase REST (via `app_platform_network`/HttpApiClient)  
**Auth:** Supabase Auth (phone OTP → JWT)  
**Font:** Tajawal  

---

## Directory Structure

```
lib/
├── main.dart                          # Entry: ProviderScope → session restore → router
├── core/
│   ├── constants.dart                 # Supabase URL, anon key
│   ├── theme/app_theme.dart           # Light/Dark themes, ThemeMode persistence
│   ├── router/app_router.dart         # GoRouter with auth guard
│   ├── providers/
│   │   ├── token_provider.dart        # JWT storage (SharedPreferences)
│   │   ├── api_client_provider.dart   # HTTP client + session logout on 401
│   │   └── initial_state_provider.dart
│   └── helpers/
│       ├── error_messages.dart        # Error types → Arabic
│       ├── error_helper.dart          # translateError()
│       └── arabic_numbers.dart        # int → Arabic words
├── presentaion/shared/                # Reusable widgets (6 files)
└── features/                          # 11 feature modules
    ├── auth/
    ├── facilities/
    ├── bookings/
    ├── wallet/
    ├── admin/
    ├── announcements/
    ├── availability/
    ├── reports/
    ├── settings/
    ├── player_ads/
    └── ads/
```

---

## Feature Module Pattern (per feature)

```
feature_name/
├── models/
│   ├── my_model.dart              # Data classes (some use dart_mappable)
│   └── models.dart                # Barrel export
├── repositories/
│   ├── feature_repository.dart    # Abstract interface
│   └── feature_repository_impl.dart  # Supabase REST calls
├── providers/
│   └── feature_provider.dart      # Notifier / FutureProvider / StateNotifier
└── presentaion/screens/
    └── feature_screen.dart        # ConsumerWidget / ConsumerStatefulWidget
```

### Layers & Data Flow

```
UI (ConsumerWidget)
    │  ref.watch(provider) / ref.read(provider.notifier).action()
    ▼
Provider (Notifier / FutureProvider / StateNotifier)
    │  delegates to repository
    ▼
Repository (abstract → impl)
    │  _apiClient.post('rpc/function_name', body: {...})
    ▼
Supabase REST API → PostgreSQL RPC function
```

- **Reads:** `ref.watch(provider)` → UI rebuilds on state change
- **Writes:** `ref.read(provider.notifier).doSomething()` → result returned as `Result<T>` (Success/Failure)
- **Error handling:** `result.when(success: ..., failure: (e) => translateError(e))`

---

## Routing (app_router.dart)

```dart
routerProvider → GoRouter with auth guard:
  - Unauthenticated → /login
  - Authenticated + on auth route → /home
  - Otherwise → requested route
```

| Route | Screen |
|-------|--------|
| `/login` | LoginScreen |
| `/register` | RegisterScreen |
| `/home` | HomeScreen (shell, tab-based by role) |
| `/facilities/:groupId` | FacilitiesScreen |
| `/create-booking` | CreateBookingScreen |
| `/my-bookings` | MyBookingsScreen |
| `/booking/:id` | BookingDetailScreen |
| `/wallet` | WalletScreen |
| `/admin/*` | Admin dashboard, pending, facilities, QR, etc. |
| `/available-slots` | AvailableSlotsScreen |
| `/player-ads` | PlayerAdsScreen |
| `/privacy` / `/terms` | Privacy/terms screens |

---

## Auth Flow

```
app start
  → try restore session (SharedPreferences)
  → if phone+token exist → verify with /rpc/get_my_profile
  → if valid → auto-login, navigate /home
  → else → /login
```

Registration requires consent checkbox (privacy + terms).

---

## API Client (api_client_provider.dart)

```dart
HttpApiClient(
  baseUrl: supabaseRestUrl,  // https://xlcmbxvqdfwlfotyvqas.supabase.co/rest/v1/
  customHandler: _responseHandler,  // Parses JSON, checks success field, handles 4xx/5xx
  tokenProvider: AppTokenProvider,  // Attaches JWT Bearer token
  defaultHeaders: { 'apikey': supabaseAnonKey },
)
```

Every RPC call:
```dart
_apiClient.post('rpc/function_name', body: { 'p_param': value }, parser: ...)
```

Returns `Result<T>`:
- `Success(data)` — HTTP 2xx, `success: true`
- `Failure(error)` — `NetworkError`, `NotFoundError`, `UnauthorizedError`, `ForbiddenError`, `ValidationError`, `ServerError`, `NoInternetError`, `TimeoutError`

All errors translate to Arabic via `translateError()`.

---

## Shared Widgets

| Widget | Location | Purpose |
|--------|----------|---------|
| `SlotPickerWidget` | `shared/slot_picker_widget.dart` | Interactive time grid: horizontal start chips + duration chips + price calculation, fine-period awareness, booked-slot blocking |
| `AppTextField` / `PasswordField` | `shared/app_text_field.dart` | Themed input fields |
| `AdBanner` | `shared/ad_banner.dart` | Auto-scrolling ad carousel with WhatsApp fallback |
| `InfoRow` | `shared/info_row.dart` | Label + value with icon |
| `showLoadingDialog` | `shared/loading_dialog.dart` | Modal loading spinner |
| `HourPickerDialog` | `shared/time_picker_dialog.dart` | Hour selection dialog + date/time formatters (`format12`, `dateLabelWithDay`, etc.) |

---

## Key Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `authStateProvider` | StateNotifier | Auth state (logged in/out, user info) |
| `authActionProvider` | StateNotifier | Action state (loading per action key) |
| `apiClientProvider` | Provider | HTTP client for REST API |
| `facilityGroupsProvider` | Notifier | List of facility groups |
| `bookingFormProvider` | Notifier | Current booking form state |
| `pendingBookingsProvider` | Notifier | Admin pending bookings list |
| `adminActionProvider` | StateNotifier | Admin action states + API calls |
| `unreadCountProvider` | Notifier | Unread announcements count |
| `walletInfoFamilyProvider` | FutureProvider.family | Wallet per group |
| `themeModeProvider` | StateNotifier | Theme mode persistence |

---

## Theme & Styling

- **Material 3** with dynamic `ColorScheme.fromSeed`
- **RTL:** `Directionality` and `TextDirection.rtl`
- **Font:** `Tajawal` (Google Fonts)
- **Theme toggle:** Light / Dark / System (persisted to SharedPreferences)

---

## Slot Picker Design (SlotPickerWidget)

```
┌─────────────────────────────────────┐
│  اختر وقت الحجز              [إلغاء] │
├─────────────────────────────────────┤
│  [status bar: اختر وقت البداية]      │
├─────────────────────────────────────┤
│  ■ متاح  ■ محجوز                     │
├─────────────────────────────────────┤
│  أوقات البداية                        │
│  [16:00] [17:00] [18:00] [19:00]...  │  ← horizontal scroll
├─────────────────────────────────────┤
│  اختر المدة                           │
│  [1س = 5000ر.ي] [2س = 10000ر.ي]     │  ← Wrap chips
├─────────────────────────────────────┤
│  ✓ 16:00 → 18:00                     │
│  2س = 10000ر.ي                       │  ← summary (when selected)
└─────────────────────────────────────┘
```

- Start times are generated from working hours, excluding booked slots
- Duration chips capped at: closing time, next booking, max_booking_hours
- Fine period (slot_fine_from → slot_fine_to) shown via subtle border

---

## Naming Conventions

| Element | Pattern | Example |
|---------|---------|---------|
| **Routes** | `/kebab-case` | `/admin/pending-bookings` |
| **RPC params** | `p_snake_case` | `p_facility_id` |
| **DB columns** | `snake_case` | `facility_group_id` |
| **Dart files** | `snake_case` | `create_booking_screen.dart` |
| **Classes** | `PascalCase` | `SlotPickerWidget` |
| **Methods/vars** | `camelCase` | `_loadSlots()` |
| **Riverpod providers** | `camelCase` | `pendingBookingsProvider` |
