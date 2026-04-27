# Mobile Feature Parity Design

Date: 2026-02-24
Branch: flutter-riverpod-buildout

## Context

Dave's web app worktree added 17 commits of new features that the Flutter mobile app lacks. This design covers implementing all 11 missing features to reach feature parity.

## Phase 1: Auth Foundation

### Email/Password Login
- Add `Phone | Email` segmented control to `login_screen.dart`
- Email tab: email field, password field (visibility toggle), sign-in/sign-up mode toggle
- Sign-up: `supabase.auth.signUp(email, password)` — min 6 chars, confirm password match
- Sign-in: `supabase.auth.signInWithPassword(email, password)`
- On success: existing `authStateProvider` handles session change → redirect

### Onboarding Vehicle Type + Fixed Route
- Extend `register_screen.dart` step 3 rider-specific fields
- Add vehicle type chip group: bike, car, truck, bus, other
- Conditional fixed-route section (bus/truck only): origin + destination via `LocationPicker`
- On submit: upsert `user_profiles` with `vehicle_type`, `fixed_route_origin` (PostGIS POINT), `fixed_route_origin_name`, `fixed_route_destination`, `fixed_route_destination_name`

## Phase 2: Data Features

### Farmer/Rider Earnings + Payout Requests
- New `features/earnings/` directory
- `EarningItem` model: id, orderId, amount, status, role, createdAt
- `EarningsSummary`: totalEarned, pendingBalance, settledBalance, totalWithdrawn, totalRequested
- `EarningsRepository`: queries `earnings` table (summary + paginated list), inserts into `payout_requests`
- `earningsSummaryProvider` (FutureProvider), `earningsListProvider(page)` (FutureProvider.family)
- `EarningsScreen`: 4 summary cards, paginated list with status badges, payout request bottom sheet
- Shared screen for farmer and rider roles (filtered by current user)
- Payout form: amount (validates against available balance), method (esewa/khalti/bank), conditional account details

### Saved Addresses (Consumer)
- New `features/addresses/` directory
- `SavedAddress` model: id, label, addressText, lat, lng, isDefault
- `AddressRepository`: CRUD on `user_addresses`, PostGIS POINT for location, partial unique index on is_default
- `addressesProvider` (AsyncNotifierProvider)
- `AddressesScreen`: list with default star badge, add/edit form with `LocationPicker`, swipe-to-delete, set-default
- Integrate into checkout as quick-pick dropdown

### Farmer Orders View
- New `features/farmer/screens/farmer_orders_screen.dart`
- `FarmerOrdersRepository` (or extend `farmer_repository.dart`): query `order_items` WHERE `farmer_id = currentUser`, join orders + listings + consumer + rider, group by order_id
- Two tabs: active (pending/matched/picked_up/in_transit) / completed (delivered/cancelled)
- Order card: items summary, consumer name, rider name, farmerSubtotal, status badge
- Inline actions for `pickup_status == 'pending_pickup'`: "Confirm Pickup" / "Mark Unavailable"

### Account Settings
- New `features/profile/screens/account_settings_screen.dart`
- Edit: full_name, phone, bio (farmer only, 1000 char limit)
- Password change section (email users only): current password → verify via `signInWithPassword`, then `updateUser(password: newPassword)`
- Read-only: email, role, member-since date
- Writes to `user_profiles` table

## Phase 3: Map & Real-time Features

### Rider Available Orders Map
- New `features/orders/screens/available_orders_screen.dart`
- `AvailableOrdersRepository`: query `orders` WHERE `status='pending' AND rider_id IS NULL AND parent_order_id IS NULL`, join order_items → produce_listings(location) + users(name)
- Map view: delivery location markers (clustered), pickup location markers (green), rider GPS position
- For bus/truck riders: display fixed_route line from `user_profiles`
- Tap marker → bottom sheet with order details (items, weight, delivery fee, address)
- "Accept Order" button: `acceptOrderDirect` — create `rider_trips` row, atomically update `orders.rider_id + rider_trip_id + status='matched'`
- Add as tab/button on rider home screen

### Voice Messages in Chat
- Extend `ChatRepository` with `uploadChatAudio(Uint8List bytes)` — uploads to `chat-audio` Supabase Storage bucket
- Add `just_audio` Flutter package for playback
- Add `record` package for microphone recording
- Chat screen: mic button (replaces send when text is empty), recording state (red dot + timer), stop → upload → send
- Message bubble: detect `message_type == 'audio'`, render play/pause button + seek bar + duration
- Request microphone permission via `permission_handler`

## Phase 4: Polish & Wiring

### Delivery ETA Badges
- Add `batchDeliveryEtas(listingIds, deliveryPointWkt)` to `ProduceRepository` (calls RPC `batch_delivery_etas`)
- Show "~X min" badge on produce cards when user has default address or GPS location
- Update `MarketplaceScreen` provider to call after listings load

### Push Notification Deep Links
- Wire `onMessageOpenedApp` in `PushNotificationService`
- Extract `data.order_id` + `data.type` from notification payload
- Route: new_order → order detail, order_matched → order detail, picked_up → order detail, in_transit → tracking, delivered → order detail
- Use GoRouter `context.go()` for navigation

### Farmer Bio Display
- Add read-only bio section to produce detail screen (farmer info card)
- Query `user_profiles.bio` alongside existing farmer data fetch
- Already editable via account settings screen

## Supabase Tables/RPCs Used

| Table/RPC | Features |
|---|---|
| `earnings` | Earnings pages |
| `payout_requests` | Earnings pages |
| `user_addresses` | Saved addresses |
| `user_profiles` (vehicle_type, fixed_route_*, bio) | Onboarding, account settings, bio, available orders |
| `orders` (pending, unassigned) | Available orders map |
| `order_items` (farmer_id filter) | Farmer orders |
| `chat-audio` storage bucket | Voice messages |
| RPC `batch_delivery_etas` | Delivery ETA |
| `supabase.auth.signUp/signInWithPassword/updateUser` | Email auth, password change |

## File Structure (New)

```
features/
  earnings/
    models/earning_item.dart
    repositories/earnings_repository.dart
    providers/earnings_provider.dart
    screens/earnings_screen.dart
  addresses/
    models/saved_address.dart
    repositories/address_repository.dart
    providers/address_provider.dart
    screens/addresses_screen.dart
```
