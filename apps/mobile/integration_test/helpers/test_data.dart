import 'package:jirisewa_mobile/core/models/user_profile.dart';

/// Test user profile for a multi-role user.
const testUserId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

final testProfile = UserProfile(
  id: testUserId,
  phone: '9812345678',
  name: 'Sita Sharma',
  role: 'consumer',
  address: 'Jiri, Dolakha',
  municipality: 'Jiri',
  lang: 'ne',
  ratingAvg: 4.5,
  ratingCount: 12,
);

final testRoles = [
  const UserRoleDetails(
    id: 'role-1',
    userId: testUserId,
    role: 'consumer',
    verified: true,
  ),
  const UserRoleDetails(
    id: 'role-2',
    userId: testUserId,
    role: 'farmer',
    farmName: 'Sita Fresh Farm',
    verified: true,
  ),
  const UserRoleDetails(
    id: 'role-3',
    userId: testUserId,
    role: 'rider',
    vehicleType: 'bike',
    vehicleCapacityKg: 50,
    verified: false,
  ),
];

/// Mock JSON responses for the Supabase REST API.
final mockOrders = [
  {
    'id': 'ord-11111111-2222-3333-4444-555555555555',
    'consumer_id': testUserId,
    'rider_id': testUserId,
    'status': 'delivered',
    'total_price': 1250,
    'delivery_fee': 150,
    'delivery_address': 'Jiri Bazaar, Dolakha',
    'payment_method': 'esewa',
    'payment_status': 'paid',
    'created_at': '2026-02-13T10:30:00Z',
  },
  {
    'id': 'ord-22222222-3333-4444-5555-666666666666',
    'consumer_id': testUserId,
    'rider_id': null,
    'status': 'pending',
    'total_price': 800,
    'delivery_fee': 100,
    'delivery_address': 'Charikot, Dolakha',
    'payment_method': 'cash',
    'payment_status': 'pending',
    'created_at': '2026-02-14T08:00:00Z',
  },
  {
    'id': 'ord-33333333-4444-5555-6666-777777777777',
    'consumer_id': testUserId,
    'rider_id': testUserId,
    'status': 'in_transit',
    'total_price': 2100,
    'delivery_fee': 200,
    'delivery_address': 'Banepa, Kavrepalanchok',
    'payment_method': 'esewa',
    'payment_status': 'held',
    'created_at': '2026-02-14T12:00:00Z',
  },
];

final mockOrderItems = [
  {
    'id': 'item-1',
    'order_id': 'ord-11111111-2222-3333-4444-555555555555',
    'farmer_id': testUserId,
    'quantity_kg': 5,
    'price_per_kg': 120,
    'subtotal': 600,
    'pickup_confirmed': true,
    'delivery_confirmed': true,
    'produce_listings': {'name_en': 'Tomatoes', 'name_ne': 'गोलभेडा'},
  },
  {
    'id': 'item-2',
    'order_id': 'ord-11111111-2222-3333-4444-555555555555',
    'farmer_id': testUserId,
    'quantity_kg': 10,
    'price_per_kg': 65,
    'subtotal': 650,
    'pickup_confirmed': false,
    'delivery_confirmed': false,
    'produce_listings': {'name_en': 'Potatoes', 'name_ne': 'आलु'},
  },
];

final mockProduceListings = [
  {
    'id': 'prod-1',
    'farmer_id': testUserId,
    'name_en': 'Tomatoes',
    'name_ne': 'गोलभेडा',
    'price_per_kg': 120,
    'available_qty_kg': 50,
    'is_active': true,
    'photos': <String>[],
    'created_at': '2026-02-10T08:00:00Z',
  },
  {
    'id': 'prod-2',
    'farmer_id': testUserId,
    'name_en': 'Potatoes',
    'name_ne': 'आलु',
    'price_per_kg': 65,
    'available_qty_kg': 200,
    'is_active': true,
    'photos': <String>[],
    'created_at': '2026-02-11T08:00:00Z',
  },
  {
    'id': 'prod-3',
    'farmer_id': 'other-farmer',
    'name_en': 'Cauliflower',
    'name_ne': 'काउली',
    'price_per_kg': 80,
    'available_qty_kg': 30,
    'is_active': true,
    'photos': <String>[],
    'created_at': '2026-02-12T08:00:00Z',
  },
  {
    'id': 'prod-4',
    'farmer_id': 'other-farmer',
    'name_en': 'Spinach',
    'name_ne': 'पालुंगो',
    'price_per_kg': 90,
    'available_qty_kg': 15,
    'is_active': true,
    'photos': <String>[],
    'created_at': '2026-02-13T08:00:00Z',
  },
];

final mockRiderTrips = [
  {
    'id': 'trip-1',
    'rider_id': testUserId,
    'origin_name': 'Jiri',
    'destination_name': 'Kathmandu',
    'departure_at': '2026-02-15T06:00:00Z',
    'status': 'scheduled',
    'remaining_capacity_kg': 30,
    'available_capacity_kg': 50,
  },
  {
    'id': 'trip-2',
    'rider_id': testUserId,
    'origin_name': 'Charikot',
    'destination_name': 'Banepa',
    'departure_at': '2026-02-14T14:00:00Z',
    'status': 'in_transit',
    'remaining_capacity_kg': 10,
    'available_capacity_kg': 50,
  },
  {
    'id': 'trip-3',
    'rider_id': testUserId,
    'origin_name': 'Kathmandu',
    'destination_name': 'Jiri',
    'departure_at': '2026-02-12T07:00:00Z',
    'status': 'completed',
    'remaining_capacity_kg': 0,
    'available_capacity_kg': 50,
  },
];

final mockUserRow = {
  'id': testUserId,
  'phone': '9812345678',
  'name': 'Sita Sharma',
  'role': 'consumer',
  'avatar_url': null,
  'address': 'Jiri, Dolakha',
  'municipality': 'Jiri',
  'lang': 'ne',
  'rating_avg': 4.5,
  'rating_count': 12,
};

final mockUserRolesRows = [
  {
    'id': 'role-1',
    'user_id': testUserId,
    'role': 'consumer',
    'farm_name': null,
    'vehicle_type': null,
    'vehicle_capacity_kg': null,
    'license_photo_url': null,
    'verified': true,
  },
  {
    'id': 'role-2',
    'user_id': testUserId,
    'role': 'farmer',
    'farm_name': 'Sita Fresh Farm',
    'vehicle_type': null,
    'vehicle_capacity_kg': null,
    'license_photo_url': null,
    'verified': true,
  },
  {
    'id': 'role-3',
    'user_id': testUserId,
    'role': 'rider',
    'farm_name': null,
    'vehicle_type': 'bike',
    'vehicle_capacity_kg': 50.0,
    'license_photo_url': null,
    'verified': false,
  },
];
