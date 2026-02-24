# JiriSewa

Farm-to-consumer marketplace connecting Nepali farmers, consumers, and delivery riders. Domain: `khetbata.xyz` / `jirisewa.com`.

## Tech Stack

- **Framework**: Next.js 16 (App Router, React 19, standalone output)
- **Language**: TypeScript 5
- **Styling**: Tailwind CSS 4
- **Database**: Supabase (PostgreSQL + PostGIS)
- **Auth**: Supabase Auth (Google OAuth + phone OTP)
- **Payments**: eSewa, Khalti, connectIPS (Nepali gateways)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Maps**: Leaflet + OpenStreetMap tiles, OSRM routing, Nominatim geocoding
- **i18n**: next-intl (English `en` + Nepali `ne`, default: `ne`)
- **Charts**: Recharts
- **Monorepo**: pnpm workspaces
- **Testing**: Playwright (e2e)

## Monorepo Structure

```
apps/web/                    # Next.js web application (@jirisewa/web)
packages/shared/             # Shared constants, enums, phone utils (@jirisewa/shared)
packages/database/           # Database type exports (@jirisewa/database)
```

## Commands

```bash
pnpm dev                     # Start dev server
pnpm build                   # Production build
pnpm lint                    # Lint all packages
pnpm type-check              # TypeScript check all packages
pnpm test:e2e                # Run smoke e2e tests (Playwright)
pnpm test:e2e:all            # Run all e2e tests (FULL_E2E=1)
```

## Environment Variables

### Public (client-safe)
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key
- `NEXT_PUBLIC_BASE_URL` - App base URL (e.g. `https://khetbata.xyz`)
- `NEXT_PUBLIC_FIREBASE_*` - Firebase config (API_KEY, AUTH_DOMAIN, PROJECT_ID, STORAGE_BUCKET, MESSAGING_SENDER_ID, APP_ID, VAPID_KEY)

### Server-only
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key (bypasses RLS)
- `ESEWA_SECRET_KEY`, `ESEWA_PRODUCT_CODE`, `ESEWA_ENVIRONMENT` - eSewa payment gateway
- `KHALTI_SECRET_KEY`, `KHALTI_ENVIRONMENT` - Khalti payment gateway
- `CONNECTIPS_MERCHANT_ID`, `CONNECTIPS_APP_ID`, `CONNECTIPS_APP_NAME`, `CONNECTIPS_APP_PASSWORD`, `CONNECTIPS_KEY_PATH`, `CONNECTIPS_ENVIRONMENT` - connectIPS gateway

## Project Layout (apps/web/src/)

```
app/
  layout.tsx                           # Root layout (just globals.css)
  [locale]/
    layout.tsx                         # Locale layout (AuthProvider, CartProvider, Header, i18n)
    page.tsx                           # Landing page
    auth/                              # Authentication
    onboarding/                        # Role selection after first login
    marketplace/                       # Public produce browsing
    produce/                           # Produce listing detail
    cart/                              # Shopping cart
    checkout/                          # Multi-step checkout
    orders/                            # Consumer order management
    customer/                          # Authenticated consumer marketplace
    farmer/                            # Farmer dashboard, listings, analytics
    rider/                             # Rider trips, route planning
    messages/                          # In-app chat
    notifications/                     # Notification preferences
    subscriptions/                     # Consumer subscription browsing
    business/                          # B2B bulk orders
    admin/                             # Platform admin panel
  api/                                 # API route handlers
components/
  ui/                                  # Button, Card, Input, Badge, SectionBlock, IconCircle
  layout/                              # Header
  map/                                 # LocationPicker, TripRouteMap, MultiStopRouteMap, OrderTrackingMap, ProduceMap
  marketplace/                         # ProduceCard, ProduceDetail, MarketplaceContent, FilterSidebar
  cart/                                # CartHeaderLink
  chat/                                # ChatBadge, OrderChatButton
  notifications/                       # NotificationBell, PushNotificationManager, NotificationPreferences
  orders/                              # OrderStatusBadge, RiderTrackingSection
  ratings/                             # RatingBadge, RatingModal, RatingsList, StarRating
  rider/                               # PingBeaconMap, PingNotification, PingNotificationPanel, TripStatusBadge
  AuthProvider.tsx                     # Supabase auth context (useAuth hook)
  LanguageSwitcher.tsx                 # en/ne toggle
  MunicipalityPicker.tsx               # Municipality search/select
lib/
  actions/                             # Server actions ("use server")
  queries/                             # Server-side data fetching
  admin/                               # Admin queries and actions
  cart/                                # CartContext (client-side, localStorage)
  hooks/                               # usePingSubscription (Supabase realtime)
  helpers/                             # Order helper utilities
  supabase/                            # Supabase client factories
  types/                               # TypeScript type definitions
  esewa.ts, khalti.ts, connectips.ts   # Payment gateway integrations
  firebase.ts                          # FCM client setup
  i18n.ts                              # Locale constants
  map.ts                               # Map utilities
  route-optimizer.ts                   # OSRM route optimization
  leaflet-icons.ts                     # Leaflet marker icons
i18n/
  routing.ts                           # next-intl routing config
  request.ts                           # next-intl request config
  navigation.ts                        # Navigation helpers
messages/
  en.json, ne.json                     # Translation files
```

---

## Database Schema

### Core Tables

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `users` | All platform users | id, phone, name, role, location (PostGIS), municipality, lang (en/ne), rating_avg, rating_count, is_admin |
| `user_roles` | Multi-role support per user | user_id, role (farmer/consumer/rider), farm_name, vehicle_type, vehicle_capacity_kg, verified, verification_status |
| `user_profiles` | OAuth profile data | id (= auth.users.id), email, full_name, avatar_url, role, onboarding_completed |

### Produce & Categories

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `produce_categories` | Product categories | name_en, name_ne, icon, sort_order |
| `produce_listings` | Farmer produce for sale | farmer_id, category_id, name_en/ne, price_per_kg, available_qty_kg, freshness_date, location (PostGIS), photos[], municipality_id, is_active |

### Orders & Payments

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `orders` | Consumer orders | consumer_id, rider_trip_id, rider_id, status (pending/matched/picked_up/in_transit/delivered/cancelled/disputed), delivery_address, delivery_location, total_price, delivery_fee (+ breakdown), payment_method (cash/esewa/khalti/connectips), payment_status (pending/escrowed/collected/settled/refunded), parent_order_id |
| `order_items` | Line items per order | order_id, listing_id, farmer_id, quantity_kg, price_per_kg, subtotal, pickup_location, pickup_status (pending_pickup/picked_up/unavailable), pickup_sequence |
| `farmer_payouts` | Payment tracking per farmer | order_id, farmer_id, amount, status (pending/settled/refunded) |
| `esewa_transactions` | eSewa payment records | order_id, transaction_uuid, product_code, amount, total_amount, status, esewa_ref_id, verified_at |
| `khalti_transactions` | Khalti payment records | order_id, purchase_order_id, pidx, amount_paisa, total_amount, status, transaction_id, khalti_fee, verified_at |
| `connectips_transactions` | connectIPS payment records | order_id, txn_id, reference_id, amount_paisa, total_amount, status, verified_at |

### Delivery & Rider

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `rider_trips` | Scheduled rider trips | rider_id, origin/destination (PostGIS), origin_name/destination_name, route, departure_at, available_capacity_kg, remaining_capacity_kg, status (scheduled/in_transit/completed/cancelled), municipality_ids |
| `rider_location_log` | GPS breadcrumbs | rider_id, trip_id, location, speed_kmh, recorded_at |
| `delivery_rates` | Fee calculation rates | base_fee_npr, per_km_rate_npr, per_kg_rate_npr, min/max_fee_npr, region_multiplier, applies_to_province |
| `order_pings` | Rider matching notifications | order_id, rider_id, trip_id, pickup_locations, delivery_location, total_weight_kg, estimated_earnings, detour_distance_m, status (pending/accepted/declined/expired), expires_at |
| `trip_stops` | Ordered stops on a trip | trip_id, type (pickup/delivery), location, sequence, completed, order references |

### Communication

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `chat_conversations` | Order-linked chat threads | order_id, participant_ids[] |
| `chat_messages` | Individual messages | conversation_id, sender_id, content, message_type (text/image/location), read_at |
| `notifications` | In-app notifications | user_id, category, title_en/ne, body_en/ne, data (JSON), read, push_sent |
| `notification_preferences` | Per-category toggles | user_id, category, enabled |
| `user_devices` | FCM device tokens | user_id, fcm_token, platform (web/android/ios), is_active |

### Subscriptions

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `subscription_plans` | Farmer-created recurring boxes | farmer_id, name_en/ne, price, frequency (weekly/biweekly/monthly), items[] (JSON array), max_subscribers, delivery_day |
| `subscriptions` | Consumer subscriptions | plan_id, consumer_id, status (active/paused/cancelled), next_delivery_date, payment_method |
| `subscription_deliveries` | Scheduled deliveries | subscription_id, order_id, scheduled_date, status (scheduled/order_created/delivered/skipped) |

### B2B / Business

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `business_profiles` | Restaurant/hotel profiles | user_id, business_name, business_type (restaurant/hotel/canteen/other), registration_number, address, phone |
| `bulk_orders` | Business bulk orders | business_profile_id, status (draft/submitted/quoted/accepted/in_progress/fulfilled/cancelled), delivery info |
| `bulk_order_items` | Items in bulk orders | bulk_order_id, listing_id, farmer_id, requested_qty_kg, quoted_price_per_kg, status |

### Geography

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `municipalities` | Nepal municipalities | name_en/ne, district, province, center (PostGIS) |
| `service_areas` | Active delivery zones | name, center_point, radius_km, is_active |
| `popular_routes` | Common rider routes | origin/destination_municipality_id, trip_count |
| `verification_documents` | Farmer verification docs | user_role_id, citizenship_photo_url, farm_photo_url, municipality_letter_url, admin_notes, reviewed_by |

### Database Functions (RPC)

| Function | Purpose |
|----------|---------|
| `search_municipalities` | Full-text municipality search with province/district filters |
| `search_produce_listings` | Geo-distance produce search |
| `find_eligible_riders` | Find riders with matching trips for an order |
| `check_point_near_route` | PostGIS: check if pickup/delivery point is near a trip route |
| `locate_point_on_route` | PostGIS: find position of point along route line |
| `create_notification` | Insert notification respecting user preferences |
| `mark_notification_read` / `mark_all_notifications_read` | Notification management |
| `get_unread_notification_count` | Count unread notifications |
| `farmer_sales_by_category` | Analytics: sales breakdown by category |
| `farmer_revenue_trend` | Analytics: daily revenue trend |
| `farmer_top_products` | Analytics: top-selling products |
| `farmer_price_benchmarks` | Analytics: price comparison vs market average |
| `farmer_fulfillment_rate` | Analytics: delivery success rate |
| `farmer_rating_distribution` | Analytics: rating score distribution |

---

## Frontend Pages

### Public Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]` | Server | Landing page with hero, how-it-works, stats, CTA | Static |
| `/[locale]/auth/login` | Client | Phone OTP login (2-step: phone -> OTP) | `useAuth()` hook (Supabase client) |
| `/[locale]/auth/register` | Client | 3-step registration (profile, role, role-specific fields) | Supabase client upsert |
| `/[locale]/onboarding` | Client | Post-OAuth role selection (farmer/rider/customer) | Supabase `user_profiles` table |
| `/[locale]/marketplace` | Server | Browse all produce with category filters | `fetchProduceListings()`, `fetchCategories()` |
| `/[locale]/marketplace/[category]` | Server | Category-filtered marketplace | `fetchProduceListings({category_id})` |
| `/[locale]/produce/[id]` | Server | Produce detail with farmer info, reviews | `fetchProduceById(id)` |

### Consumer Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]/customer` | Server | Authenticated marketplace (freshness-sorted) | `fetchProduceListings({sort_by: "freshness"})` |
| `/[locale]/cart` | Client | Shopping cart (localStorage-backed) | `useCart()` hook |
| `/[locale]/checkout` | Client | Multi-step: location -> payment method -> review -> confirm | `calculateDeliveryFee()`, `placeOrder()` |
| `/[locale]/orders` | Client | Order list with active/completed tabs | `listOrders()`, `GET /api/auth/session` |
| `/[locale]/orders/[id]` | Client | Order detail with status timeline, tracking, actions | `getOrder()`, `cancelOrder()`, `confirmDelivery()`, `retryPayment*()`, `checkReorderAvailability()` |
| `/[locale]/subscriptions` | Client | Browse/manage subscription plans | `listSubscriptionPlans()`, `getMySubscriptions()`, `subscribeToPlan()`, `pauseSubscription()`, `resumeSubscription()`, `cancelSubscription()` |
| `/[locale]/messages` | Client | Conversation list with unread badges | `listConversations()` |
| `/[locale]/messages/[conversationId]` | Client | Chat interface (text, image, location) | `getMessages()`, `sendMessage()`, `uploadChatImage()`, `markConversationRead()`, Supabase realtime |
| `/[locale]/notifications` | Server | Notification preferences | `NotificationPreferences` component |

### Farmer Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]/farmer` | Server | Farmer landing/redirect | Static |
| `/[locale]/farmer/dashboard` | Server | Stats, active listings, quick links | `getFarmerDashboardData()`, `getVerificationStatus()` |
| `/[locale]/farmer/listings/new` | Server | Create new produce listing | `getCategories()` |
| `/[locale]/farmer/listings/[id]/edit` | Server | Edit existing listing | `getFarmerListing(id)`, `getCategories()` |
| `/[locale]/farmer/analytics` | Server | Revenue charts, top products, price benchmarks, fulfillment, ratings | `getFarmerAnalytics(days)` (wraps 6 RPC calls) |
| `/[locale]/farmer/bulk-orders` | Client | View/respond to business bulk orders | `listFarmerBulkOrders()`, `quoteBulkOrderItem()`, `rejectBulkOrderItem()` |
| `/[locale]/farmer/subscriptions` | Client | Create/manage subscription plans | `getFarmerSubscriptionPlans()`, `createSubscriptionPlan()`, `toggleSubscriptionPlan()` |
| `/[locale]/farmer/verification` | Server | Submit verification documents | `getVerificationStatus()` |

### Rider Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]/rider/dashboard` | Client | Trip management with tabs (upcoming/active/completed) + ping panel | `listTrips()`, `usePingSubscription` |
| `/[locale]/rider/trips/new` | Client | 4-step trip creation (origin, destination, details, review) | `createTrip()`, OSRM `fetchRoute()` |
| `/[locale]/rider/trips/[id]` | Client | Trip detail with route map, stops, matched orders, pickup actions | `getTrip()`, `listOrdersByTrip()`, `listTripStops()`, `startTrip()`, `completeTrip()`, `cancelTrip()`, `confirmFarmerPickup()`, `markItemsUnavailable()`, `startDelivery()`, `buildStopsFromOrders()`, `optimizeTripRoute()` |
| `/[locale]/rider/trips/[id]/plan` | Client | Route planning with stop optimization | `getTrip()`, `listTripStops()`, `listOrdersByTrip()`, `optimizeTripRoute()` |
| `/[locale]/rider/navigation-lab` | Client | Map component showcase (dev/test page) | Static sample data |

### Business (B2B) Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]/business/register` | Client | Business profile registration | `getBusinessProfile()`, `createBusinessProfile()` |
| `/[locale]/business/dashboard` | Client | Business stats and recent orders | `getBusinessProfile()`, `listBulkOrders()` |
| `/[locale]/business/orders` | Client | Create/list bulk orders (debounced produce search) | `listBulkOrders()`, `createBulkOrder()`, `GET /api/produce` |
| `/[locale]/business/orders/[id]` | Client | Bulk order detail with farmer quotes | `getBulkOrder()`, `acceptBulkOrder()`, `cancelBulkOrder()` |

### Admin Pages

| Route | Type | Description | Data Source |
|-------|------|-------------|-------------|
| `/[locale]/admin` | Server | Platform stats dashboard | `getPlatformStats()` |
| `/[locale]/admin/layout` | Server | Admin layout with sidebar (force-dynamic) | `requireAdmin()` |
| `/[locale]/admin/users` | Server | User list with search/filter | `getUsers()` |
| `/[locale]/admin/users/[id]` | Server | User detail with roles | `getUserRoles()` |
| `/[locale]/admin/orders` | Server | Order list with status filter | `getOrders()` |
| `/[locale]/admin/orders/[id]` | Server | Order detail with items, actions (resolve/cancel) | `getOrderDetail()`, `updateOrderStatus()`, `forceResolveOrder()`, `cancelOrder()` |
| `/[locale]/admin/disputes` | Server | Disputed orders list | `getDisputedOrders()` |
| `/[locale]/admin/farmers` | Server | Farmer verification queue | `getUnverifiedFarmers()`, `verifyFarmer()`, `rejectFarmerVerification()` |

---

## API Routes

| Route | Methods | Description | Auth |
|-------|---------|-------------|------|
| `GET /api/auth/callback` | GET | OAuth callback: exchange code, create profile, redirect to onboarding or dashboard | Edge runtime, Supabase auth |
| `GET /api/auth/session` | GET | Return current user session | Edge runtime, Supabase auth |
| `GET /api/categories` | GET | List all produce categories | None |
| `GET /api/produce` | GET | Browse produce with filters (category, price, location, search, sort, pagination) | None |
| `GET /api/produce/[id]` | GET | Single produce listing detail | None |
| `GET /api/users/[id]/ratings` | GET | Paginated public user ratings | None |
| `GET /api/esewa/success` | GET | eSewa payment success callback: verify signature, check with eSewa API, update transaction + order | Service role |
| `GET /api/esewa/failure` | GET | eSewa payment failure/cancel callback | Service role |
| `GET /api/khalti/callback` | GET | Khalti payment callback: verify with Khalti lookup API, update transaction + order | Service role |
| `GET,POST /api/connectips/success` | GET, POST | connectIPS success callback: verify with API, update transaction + order | Service role |
| `GET,POST /api/connectips/failure` | GET, POST | connectIPS failure/cancel callback | Service role |

---

## Server Actions (lib/actions/)

### orders.ts
- `placeOrder(input)` - Create order with items, payouts, payment gateway setup
- `listOrders(statusFilter?)` - Consumer's orders
- `getOrder(orderId)` - Single order with all relationships
- `cancelOrder(orderId)` - Cancel order, refund payouts and digital payments
- `confirmDelivery(orderId)` - Mark delivered, settle payouts, release escrow
- `confirmPickup(orderId)` - Legacy single-farmer pickup confirmation
- `confirmFarmerPickup(orderId, farmerId)` - Per-farmer pickup confirmation
- `markItemsUnavailable(orderId, farmerId)` - Mark items unavailable, adjust totals
- `startDelivery(orderId)` - Transition to in_transit
- `listOrdersByTrip(tripId)` - Orders matched to a rider trip
- `getFarmerPayouts(farmerId)` - Payout aggregation
- `checkReorderAvailability(orderId)` - Check if previous order items are still available

### trips.ts
- `createTrip(input)` - Create rider trip with PostGIS points
- `listTrips(statusFilter?)` - Rider's trips
- `getTrip(tripId)` - Single trip detail
- `updateTrip(tripId, input)` - Edit scheduled trip
- `startTrip(tripId)` - Begin trip (scheduled -> in_transit)
- `completeTrip(tripId)` - Finish trip (in_transit -> completed)
- `cancelTrip(tripId)` - Cancel scheduled trip

### pings.ts
- `findAndPingRiders(orderId)` - Find eligible riders via RPC, create ping records
- `acceptPing(pingId)` - Atomically match order to rider, update trip, recalculate route via OSRM
- `declinePing(pingId)` - Decline a ping
- `listPendingPings()` - Rider's active pings

### trip-stops.ts
- `listTripStops(tripId)` - Get ordered stops for a trip
- `createTripStop(input)` - Add stop with PostGIS point
- `completeTripStop(stopId)` - Mark stop completed
- `optimizeTripRoute(tripId)` - OSRM-based route optimization, update sequences/ETAs
- `buildStopsFromOrders(tripId)` - Generate pickup/delivery stops from matched orders

### payments.ts
- `retryEsewaPayment(orderId)` - Create new eSewa transaction, return form data
- `retryKhaltiPayment(orderId)` - Create Khalti transaction, call initiation API
- `retryConnectIPSPayment(orderId)` - Create connectIPS transaction, return form data
- `getEsewaTransactionStatus(orderId)` - Check latest eSewa transaction status

### matching.ts
- `findMatchingTrips(input)` - Find trips near pickup/delivery points using PostGIS
- `computePickupSequence(tripId, farmerPoints)` - Sort farmers along trip route

### ratings.ts (only action file with real auth)
- `submitRating(input)` - Create rating with full validation (auth, order status, duplicate check)
- `getOrderRatingStatus(orderId)` - Who can/has rated for an order
- `getUserRatings(userId)` - Paginated ratings received

### chat.ts
- `getOrCreateConversation(orderId, otherUserId)` - Find or create chat thread
- `addRiderToConversation(orderId, riderId)` - Add rider to existing conversation
- `sendMessage(conversationId, content, messageType?)` - Send text/image/location message
- `listConversations()` - All conversations with last message and unread count
- `getMessages(conversationId, limit?, beforeId?)` - Paginated messages with cursor
- `markConversationRead(conversationId)` - Mark all messages as read
- `getTotalUnreadCount()` - Total unread across all conversations
- `uploadChatImage(formData)` - Upload image to Supabase Storage
- `getConversationDetails(conversationId)` - Conversation metadata

### notifications.ts
- `registerDeviceToken(fcmToken, platform)` - Register FCM device
- `unregisterDeviceToken(fcmToken)` - Deactivate device
- `listNotifications(limit?, offset?)` - Paginated notifications
- `getUnreadCount()` - Unread notification count
- `markNotificationRead(notificationId)` / `markAllNotificationsRead()` - Mark read
- `getNotificationPreferences()` / `updateNotificationPreference(category, enabled)` - Manage preferences
- `triggerNotification(payload)` - Send via Supabase edge function
- `notifyOrderMatched`, `notifyRiderPickedUp`, `notifyRiderArriving`, `notifyOrderDelivered`, `notifyFarmerNewOrder`, `notifyFarmerRiderArriving`, `notifyRiderNewOrderMatch`, `notifyRiderTripReminder`, `notifyRiderDeliveryConfirmed` - Template notification senders

### subscriptions.ts
- `getFarmerSubscriptionPlans()` / `createSubscriptionPlan(input)` / `toggleSubscriptionPlan(planId, isActive)` - Farmer plan management
- `listSubscriptionPlans()` - Browse active plans
- `getMySubscriptions()` / `subscribeToPlan(planId, paymentMethod)` / `pauseSubscription(id)` / `resumeSubscription(id)` / `cancelSubscription(id)` - Consumer subscription management

### business.ts
- `getBusinessProfile()` / `createBusinessProfile(input)` / `updateBusinessProfile(input)` - Business profile CRUD
- `createBulkOrder(input)` - Multi-item bulk order creation
- `listBulkOrders(statusFilter?)` / `getBulkOrder(orderId)` - Bulk order queries
- `cancelBulkOrder(orderId)` / `acceptBulkOrder(orderId)` - Bulk order actions
- `listFarmerBulkOrders()` / `quoteBulkOrderItem(itemId, price, notes?)` / `rejectBulkOrderItem(itemId, notes?)` - Farmer-side bulk order management

### delivery-fee.ts
- `calculateDeliveryFee(input)` - Compute delivery fee using OSRM distance + weight-based formula

### tracking.ts
- `getLatestRiderLocation(tripId)` - Latest GPS point for a trip
- `getTripRouteData(tripId)` - Trip route geometry

### municipalities.ts
- `searchMunicipalitiesAction(query, province?)` - Municipality search via RPC

---

## Auth Architecture

- **OAuth**: Google sign-in via Supabase Auth. Callback at `/api/auth/callback` creates `user_profiles` row, redirects to onboarding if new user.
- **Phone OTP**: Supabase `signInWithOtp` for phone-based login.
- **Session**: `GET /api/auth/session` for client-side session checks. Server components use `createSupabaseServerClient()` with cookie-based sessions.
- **Admin auth**: `requireAdmin(locale)` checks `users.is_admin` flag, redirects if not admin.
- **Service role**: Most server actions use `createServiceRoleClient()` (bypasses RLS). Only `ratings.ts` uses authenticated client.
- **Demo IDs**: Many actions use hardcoded demo user IDs (DEMO_CONSUMER_ID, DEMO_RIDER_ID, DEMO_FARMER_ID) - auth migration in progress.

## Payment Flow

1. Consumer selects payment method at checkout (cash, eSewa, Khalti, connectIPS)
2. `placeOrder()` creates order + transaction record for digital payments
3. **eSewa/connectIPS**: Returns form data for browser redirect to payment gateway
4. **Khalti**: Calls Khalti API to get payment URL, returns for redirect
5. Gateway callbacks hit `/api/{gateway}/success` or `/api/{gateway}/failure`
6. Success callback: verify signature/API, update transaction status to COMPLETE, set order payment_status to "escrowed"
7. On delivery confirmation: release escrow, settle farmer payouts

## Rider Matching Flow

1. Order placed -> `findAndPingRiders()` finds eligible riders via PostGIS RPC
2. Eligible riders get `order_pings` records (5-minute expiry)
3. Rider sees ping via `usePingSubscription` (Supabase realtime)
4. `acceptPing()` atomically: match order, deduct trip capacity, create trip stops, recalculate OSRM route, add rider to chat
5. Other pings for same order get expired

## Key Patterns

- **Server vs Client components**: Server components for data-heavy pages (farmer dashboard, admin, marketplace). Client components for interactive pages (checkout, chat, rider trip management).
- **Server actions**: All mutations go through `lib/actions/` with `"use server"` directive. Return `ActionResult<T>` type (`{ data: T }` or `{ error: string }`).
- **PostGIS**: Location data stored as PostGIS geography types. Distance calculations, route matching, and point-near-route checks via Supabase RPC functions.
- **Multi-farmer orders**: A single consumer order can include items from multiple farmers. Each farmer gets separate payout tracking. Pickup happens per-farmer.
- **Cart**: Client-side only via React context + localStorage (`jirisewa_cart` key). No server-side cart.
- **i18n**: All user-facing content bilingual (en/ne). Database stores both `name_en` and `name_ne`. UI uses next-intl with JSON message files.
- **Realtime**: Supabase realtime subscriptions for rider pings (`usePingSubscription` hook) and chat messages.

## Shared Package (@jirisewa/shared)

Exports from `packages/shared/src/`:
- **Constants**: locales, map config (tile URL, OSRM, Nominatim, Nepal bounds, Jiri center), ping config (expiry, max detour, max pings)
- **Enums**: UserRole, OrderStatus, TripStatus, PaymentMethod, PaymentStatus, VehicleType, PingStatus, MessageType, BusinessType, BulkOrderStatus, BulkItemStatus, SubscriptionFrequency, SubscriptionStatus, StopType, etc.
- **Phone utils**: `normalizePhone()`, `isValidNepalPhone()`, `toE164()` for Nepal phone numbers
