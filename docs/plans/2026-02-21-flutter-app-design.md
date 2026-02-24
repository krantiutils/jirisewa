# Flutter App Full Build-Out Design

**Date**: 2026-02-21
**Scope**: Full feature parity with web app + Riverpod migration
**Architecture**: Feature-First Riverpod

---

## 1. Overview

Build the JiriSewa Flutter mobile app (`apps/mobile/`) to full feature parity with the Next.js web app. This involves:

1. **Full Riverpod migration** — refactor all existing screens from StatefulWidget + InheritedNotifier to Riverpod providers
2. **All missing features** — cart, checkout, payments, chat, notifications, ratings, trip creation, farmer tools, subscriptions, business/B2B, analytics

The app talks directly to Supabase (not through the Next.js API routes). Payment verification callbacks use the existing web API routes.

---

## 2. Architecture

### Pattern: Feature-First Riverpod

```
lib/
  core/
    providers/         # Supabase client, session, auth providers
    models/            # Shared data classes
    routing/           # GoRouter with Riverpod redirect
    theme.dart
    constants/
    services/          # Push notifications, location tracking, geocoding
  features/
    auth/
      providers/       # authStateProvider, sessionProvider, userProfileProvider
      repositories/    # AuthRepository
      screens/         # LoginScreen, RegisterScreen, OnboardingScreen
    marketplace/
      providers/       # listingsProvider, categoriesProvider
      repositories/    # ProduceRepository
      screens/         # MarketplaceScreen, ProduceDetailScreen
      widgets/         # ProduceCard, FilterBar, ListingsMap
    cart/
      providers/       # cartProvider (SharedPreferences backed)
      models/          # Cart, CartItem
      screens/         # CartScreen
      widgets/         # CartBadge
    checkout/
      providers/       # checkoutProvider, deliveryFeeProvider
      screens/         # CheckoutScreen (multi-step)
    orders/
      providers/       # ordersProvider, orderDetailProvider
      repositories/    # OrderRepository
      screens/         # OrdersScreen, OrderDetailScreen, OrderTrackingScreen
      widgets/         # OrderStatusBadge, StatusTimeline
    trips/
      providers/       # tripsProvider, tripDetailProvider, tripStopsProvider
      repositories/    # TripRepository
      screens/         # TripsScreen, TripCreationScreen, TripDetailScreen, RoutePlanScreen
      widgets/         # TripStatusBadge, PingBeaconMap, RouteMap
    chat/
      providers/       # conversationsProvider, messagesProvider (realtime)
      repositories/    # ChatRepository
      screens/         # ConversationsScreen, ChatScreen
      widgets/         # ChatBadge, MessageBubble
    notifications/
      providers/       # notificationsProvider, unreadCountProvider
      repositories/    # NotificationRepository
      screens/         # NotificationsScreen, NotificationPreferencesScreen
      widgets/         # NotificationBell
    payments/
      providers/       # paymentProvider
      repositories/    # PaymentRepository
      services/        # EsewaService, KhaltiService, ConnectIPSService
    ratings/
      providers/       # userRatingsProvider, orderRatingStatusProvider
      repositories/    # RatingRepository
      widgets/         # RatingModal, StarRating, RatingBadge, RatingsList
    tracking/
      providers/       # riderLocationProvider (realtime)
      services/        # LocationTrackingService
      screens/         # TripTrackingScreen
      widgets/         # OrderTrackingMap
    profile/
      providers/       # profileProvider
      screens/         # ProfileScreen, ProfileEditScreen
    farmer/
      providers/       # farmerDashboardProvider, analyticsProvider, verificationProvider
      repositories/    # FarmerRepository
      screens/         # CreateListingScreen, EditListingScreen, AnalyticsScreen, VerificationScreen
    subscriptions/
      providers/       # subscriptionPlansProvider, mySubscriptionsProvider
      repositories/    # SubscriptionRepository
      screens/         # SubscriptionBrowseScreen, FarmerSubscriptionsScreen
    business/
      providers/       # businessProfileProvider, bulkOrdersProvider
      repositories/    # BusinessRepository
      screens/         # BusinessRegisterScreen, BusinessDashboardScreen, BulkOrdersScreen, BulkOrderDetailScreen
    shell/
      app_shell.dart   # Bottom nav with role-aware tabs
      role_switcher.dart
```

### State Management

- **Riverpod** with `flutter_riverpod` + `riverpod_annotation` (code-gen)
- Data classes: manual Dart classes with `fromJson`/`toJson` (no freezed)
- Cart: `NotifierProvider` backed by `SharedPreferences`
- Realtime: `StreamProvider` wrapping Supabase realtime channels

### Core Providers

```dart
// Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(supabaseProvider).auth.onAuthStateChange;
});

// Current session
final sessionProvider = Provider<Session?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session;
});

// User profile + roles (async, auto-refresh on auth change)
final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(...);

// Active role
final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String>(...);

// Auth status for routing
final authStatusProvider = Provider<AuthStatus>((ref) => ...);
```

### Repository Pattern

Each feature has a repository class injected via provider:

```dart
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.read(supabaseProvider));
});

class OrderRepository {
  final SupabaseClient _client;
  OrderRepository(this._client);

  Future<List<Order>> listOrders({String? status, required String userId, required String role}) async { ... }
  Future<OrderDetail> getOrder(String id) async { ... }
  Future<void> cancelOrder(String id) async { ... }
  Future<void> confirmDelivery(String id) async { ... }
  Future<void> placeOrder(PlaceOrderInput input) async { ... }
}
```

---

## 3. Navigation

### Route Structure

```
/login                          -> LoginScreen
/register                       -> RegisterScreen
/onboarding                     -> OnboardingScreen

--- StatefulShellRoute (bottom nav) ---
/home                           -> HomeScreen (role-aware)
/marketplace                    -> MarketplaceScreen
/marketplace/:category          -> Category-filtered
/produce/:id                    -> ProduceDetailScreen
/trips                          -> TripsScreen
/trips/new                      -> TripCreationScreen
/trips/:id                      -> TripDetailScreen
/trips/:id/plan                 -> RoutePlanScreen
/orders                         -> OrdersScreen
/orders/:id                     -> OrderDetailScreen
/orders/:id/tracking            -> OrderTrackingScreen
/cart                           -> CartScreen
/checkout                       -> CheckoutScreen
/profile                        -> ProfileScreen
/profile/edit                   -> ProfileEditScreen

--- Full-screen routes ---
/chat                           -> ConversationsScreen
/chat/:conversationId           -> ChatScreen
/notifications                  -> NotificationsScreen
/notifications/preferences      -> NotificationPreferencesScreen
/farmer/listings/new            -> CreateListingScreen
/farmer/listings/:id/edit       -> EditListingScreen
/farmer/analytics               -> FarmerAnalyticsScreen
/farmer/verification            -> VerificationScreen
/farmer/subscriptions           -> FarmerSubscriptionsScreen
/farmer/bulk-orders             -> FarmerBulkOrdersScreen
/business/register              -> BusinessRegisterScreen
/business/dashboard             -> BusinessDashboardScreen
/business/orders                -> BulkOrdersScreen
/business/orders/:id            -> BulkOrderDetailScreen
/subscriptions                  -> SubscriptionBrowseScreen
```

### Bottom Nav (role-aware)
- **Consumer**: Home | Marketplace | Orders | Profile
- **Rider**: Home | Trips | Orders | Profile
- **Farmer**: Home | Marketplace | Orders | Profile

### Shell Header Actions
- Cart icon with item count badge (consumer only)
- Chat icon with unread conversation count
- Notification bell with unread count

---

## 4. Feature Details

### 4.1 Auth (migrate existing)

**Screens**: LoginScreen, RegisterScreen, OnboardingScreen

**LoginScreen**: Phone OTP (exists). Add Google OAuth button using `supabase_flutter` OAuth flow with deep link callback.

**RegisterScreen**: 3-step form (exists). Migrate to Riverpod.

**OnboardingScreen**: Post-OAuth role selection (new). Shown when user authenticates via Google but has no `user_profiles` row.

**Providers**:
- `authStateProvider` — streams `onAuthStateChange`
- `userProfileProvider` — fetches `users` + `user_roles` tables
- `activeRoleProvider` — tracks current role, persists preference

### 4.2 Marketplace (migrate + enhance)

**Screens**: MarketplaceScreen, ProduceDetailScreen

**MarketplaceScreen**: Browse all produce (exists). Add category filter tabs, search bar, price range filter. Farmer view: my listings + pending pickups (exists).

**ProduceDetailScreen** (new): Full produce detail with photo carousel, farmer info, ratings, add-to-cart button.

**Providers**:
- `categoriesProvider` — fetch `produce_categories`
- `produceListingsProvider` — fetch `produce_listings` with filters (category, search, price range)
- `produceDetailProvider` — fetch single listing with farmer data + ratings

### 4.3 Cart (new)

**Screen**: CartScreen

**Behavior**: Mirrors web's localStorage cart. Items from multiple farmers. Quantity adjustment. Remove items. Shows subtotal per farmer + grand total.

**Provider**: `cartProvider` — `NotifierProvider<CartNotifier, Cart>` backed by SharedPreferences. Serializes cart as JSON.

### 4.4 Checkout (new)

**Screen**: CheckoutScreen (multi-step)

**Steps**:
1. **Location**: Delivery address with map picker (reuse existing LocationPicker widget)
2. **Payment method**: Cash / eSewa / Khalti / connectIPS selection
3. **Review**: Order summary with delivery fee calculation
4. **Confirm**: Place order, handle payment redirect

**Providers**:
- `checkoutProvider` — step state, selected payment method, delivery location
- `deliveryFeeProvider` — calls OSRM for distance, computes fee based on weight + distance

### 4.5 Payments (new)

**Services**:
- `EsewaService`: Build form data, launch eSewa via `url_launcher`. Deep link callback `jirisewa://esewa/success`.
- `KhaltiService`: Call Khalti initiation API, launch payment URL. Deep link callback `jirisewa://khalti/callback`.
- `ConnectIPSService`: Use `webview_flutter` for POST redirect flow.

All payment verification happens server-side via existing `/api/{gateway}/success` routes. The mobile app receives the result via deep link and refreshes order status.

**Deep Link Setup**:
- Android: intent filters in `AndroidManifest.xml`
- iOS: URL schemes in `Info.plist`

### 4.6 Orders (migrate + enhance)

**Screens**: OrdersScreen, OrderDetailScreen, OrderTrackingScreen

**OrdersScreen**: Tabbed (Active / Completed). Shows all orders for current role.

**OrderDetailScreen**: Full status timeline, order items with farmer info, payment status. Actions: cancel, confirm delivery, retry payment, reorder.

**OrderTrackingScreen** (new): Live map showing rider position (Supabase realtime on `rider_location_log`), route line, estimated arrival.

**Providers**:
- `ordersProvider` — paginated order list with status filter
- `orderDetailProvider` — full order with items, farmer payouts, rider info
- `riderLocationProvider` — realtime stream of rider GPS for tracking map

### 4.7 Trips (migrate + enhance)

**Screens**: TripsScreen, TripCreationScreen, TripDetailScreen, RoutePlanScreen

**TripsScreen**: Existing trip list with ping subscription. Migrate to Riverpod.

**TripCreationScreen** (new): 4-step form:
1. Origin (map picker + municipality search)
2. Destination (map picker + municipality search)
3. Details (departure date/time, capacity kg, vehicle info)
4. Review (route preview via OSRM, confirm)

**TripDetailScreen**: Route map, matched orders, trip stops. Actions: start trip, per-farmer pickup confirmation, mark items unavailable, complete trip.

**RoutePlanScreen** (new): OSRM-optimized stop ordering. Drag to reorder stops. Recalculate route.

**Providers**:
- `tripsProvider` — trip list with status filter
- `tripDetailProvider` — trip with orders, stops, pings
- `pendingPingsProvider` — realtime stream of `order_pings`
- `tripStopsProvider` — ordered stops for a trip

### 4.8 Chat (new)

**Screens**: ConversationsScreen, ChatScreen

**ConversationsScreen**: List of order-linked conversations with last message preview, unread badge, participant names.

**ChatScreen**: Message list with realtime updates. Text input + image upload + location sharing. Auto-scroll to latest. Mark as read on open.

**Providers**:
- `conversationsProvider` — fetch conversations with unread counts
- `messagesProvider` — realtime stream of messages for a conversation
- `unreadChatCountProvider` — total unread across all conversations

### 4.9 Notifications (new)

**Screens**: NotificationsScreen, NotificationPreferencesScreen

**NotificationsScreen**: Paginated list of notifications. Tap to mark read + navigate to relevant screen.

**NotificationPreferencesScreen**: Toggle per-category notification preferences.

**Providers**:
- `notificationsProvider` — paginated notifications list
- `unreadNotifCountProvider` — unread count for badge
- `notifPreferencesProvider` — per-category toggles

### 4.10 Ratings (new)

**Widgets**: RatingModal, StarRating, RatingBadge, RatingsList

**RatingModal**: Bottom sheet with star selection + comment. Validates: order must be delivered, no duplicate ratings.

**RatingsList**: Paginated list of ratings received, shown on profile and produce detail.

**Providers**:
- `orderRatingStatusProvider` — who can/has rated for an order
- `userRatingsProvider` — paginated ratings for a user

### 4.11 Farmer Features (new)

**Screens**: CreateListingScreen, EditListingScreen, FarmerAnalyticsScreen, VerificationScreen

**CreateListingScreen**: Form with photo upload, category selection, pricing, quantity, freshness date, location picker.

**EditListingScreen**: Same form pre-filled with existing data.

**FarmerAnalyticsScreen**: Charts showing revenue trend, sales by category, top products, price benchmarks, fulfillment rate, rating distribution. Uses Supabase RPC functions.

**VerificationScreen**: Upload citizenship photo, farm photo, municipality letter. Check verification status.

### 4.12 Subscriptions (new)

**Screens**: SubscriptionBrowseScreen, FarmerSubscriptionsScreen

**Consumer**: Browse farmer subscription plans. Subscribe with payment method selection. Manage (pause/resume/cancel) existing subscriptions.

**Farmer**: Create subscription plans (name, price, frequency, items, max subscribers). Toggle active/inactive.

### 4.13 Business/B2B (new)

**Screens**: BusinessRegisterScreen, BusinessDashboardScreen, BulkOrdersScreen, BulkOrderDetailScreen

**BusinessRegisterScreen**: Business profile (name, type, registration number, address, phone).

**BulkOrdersScreen**: Create bulk orders with multiple items. Search produce with debounce.

**BulkOrderDetailScreen**: View farmer quotes, accept/cancel bulk order.

### 4.14 Profile (migrate + enhance)

**Screens**: ProfileScreen, ProfileEditScreen

Add: language toggle (en/ne), sign out, link to notifications preferences, link to farmer verification (if farmer).

---

## 5. Payment Flow (Mobile-Specific)

```
Consumer selects payment method
  |
  v
placeOrder() creates order + transaction record in Supabase
  |
  +-- Cash: done, order status = pending
  |
  +-- eSewa:
  |     1. Build form params (amount, product_code, transaction_uuid, signed message)
  |     2. url_launcher opens eSewa payment page
  |     3. eSewa redirects to /api/esewa/success (web callback)
  |     4. Web callback verifies, updates DB
  |     5. Deep link jirisewa://esewa/success?order_id=X brings user back
  |     6. App refreshes order status
  |
  +-- Khalti:
  |     1. Call Khalti initiation API (via Supabase edge function or direct)
  |     2. url_launcher opens Khalti payment URL
  |     3. Khalti redirects to /api/khalti/callback (web callback)
  |     4. Web callback verifies, updates DB
  |     5. Deep link jirisewa://khalti/callback?order_id=X brings user back
  |     6. App refreshes order status
  |
  +-- connectIPS:
        1. Build form params with RSA signature
        2. webview_flutter loads connectIPS form (POST redirect)
        3. connectIPS redirects to /api/connectips/success
        4. Web callback verifies, updates DB
        5. Deep link brings user back
        6. App refreshes order status
```

---

## 6. Realtime Subscriptions

| Feature | Table | Event | Provider |
|---------|-------|-------|----------|
| Rider pings | `order_pings` | INSERT, UPDATE | `pendingPingsProvider` |
| Chat messages | `chat_messages` | INSERT | `messagesProvider` |
| Order status | `orders` | UPDATE | `orderDetailProvider` (auto-refresh) |
| Rider location | `rider_location_log` | INSERT | `riderLocationProvider` |

---

## 7. i18n

- `flutter_localizations` + ARB files
- Mirror keys from web's `messages/en.json` and `messages/ne.json`
- Language preference: `users.lang` field
- Default: Nepali (`ne`)

---

## 8. Dependencies

### New
```yaml
flutter_riverpod: ^2.6.1
riverpod_annotation: ^2.6.1
shared_preferences: ^2.3.0
url_launcher: ^6.3.0
webview_flutter: ^4.10.0
image_picker: ^1.1.2
cached_network_image: ^3.4.1
intl: ^0.20.0
fl_chart: ^0.70.0              # Analytics charts (replaces Recharts)
```

### Existing (keep)
```yaml
flutter_map: ^8.2.2
latlong2: ^0.9.1
geolocator: ^14.0.2
go_router: ^15.1.2
http: ^1.6.0
supabase_flutter: ^2.8.0
firebase_core: ^3.14.0
firebase_messaging: ^15.2.6
```

### Dev
```yaml
riverpod_generator: ^2.6.3
build_runner: ^2.4.0
custom_lint: ^0.7.0
riverpod_lint: ^2.6.3
```

---

## 9. Design System

Follow `ui.md` exactly:
- Zero box shadows — flat design
- Colors: primary=#3B82F6, secondary=#10B981, accent=#F59E0B, bg=#FFFFFF, fg=#111827, muted=#F3F4F6
- Font: Outfit (geometric sans-serif)
- Radius: 6px (rounded-md) or 8px (rounded-lg)
- Buttons: h-14 to h-16 for touch targets, scale transform on press
- Cards: solid bg color, no shadow, generous padding
- Inputs: gray-100 bg, no border, focus: white bg + 2px primary border
- Role colors: consumer=blue, farmer=emerald, rider=amber

---

## 10. Build Order

1. **Phase 0**: Riverpod setup + core providers + migrate existing screens
2. **Phase 1**: Cart + Checkout + Payments (consumer purchase flow)
3. **Phase 2**: Trip creation + route planning (rider creation flow)
4. **Phase 3**: Chat + Notifications (communication layer)
5. **Phase 4**: Ratings + Farmer tools (listings, analytics, verification)
6. **Phase 5**: Subscriptions + Business/B2B
7. **Phase 6**: i18n + polish + deep links
