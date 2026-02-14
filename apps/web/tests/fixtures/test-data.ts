/**
 * Test data fixtures for E2E tests.
 *
 * These represent the structure of data that would be seeded
 * into the test database during global setup.
 */

export interface ProduceFixture {
  name_en: string;
  name_ne: string;
  price_per_kg: number;
  available_qty_kg: number;
  category_name: string;
}

export interface TripFixture {
  origin_name: string;
  destination_name: string;
  available_capacity_kg: number;
  departure_offset_hours: number;
}

export interface OrderFixture {
  items: Array<{
    produce_name: string;
    quantity_kg: number;
  }>;
  status: string;
}

/**
 * Sample produce listings for testing the marketplace.
 */
export const PRODUCE_LISTINGS: ProduceFixture[] = [
  {
    name_en: "Fresh Tomatoes",
    name_ne: "ताजा गोलभेडा",
    price_per_kg: 80,
    available_qty_kg: 50,
    category_name: "Vegetables",
  },
  {
    name_en: "Organic Rice",
    name_ne: "जैविक चामल",
    price_per_kg: 120,
    available_qty_kg: 100,
    category_name: "Grains",
  },
  {
    name_en: "Mountain Potatoes",
    name_ne: "पहाडी आलु",
    price_per_kg: 45,
    available_qty_kg: 200,
    category_name: "Vegetables",
  },
  {
    name_en: "Fresh Spinach",
    name_ne: "ताजा पालुङ्गो",
    price_per_kg: 60,
    available_qty_kg: 30,
    category_name: "Vegetables",
  },
];

/**
 * Sample rider trips for testing trip-related flows.
 */
export const RIDER_TRIPS: TripFixture[] = [
  {
    origin_name: "Jiri",
    destination_name: "Kathmandu",
    available_capacity_kg: 100,
    departure_offset_hours: 24,
  },
  {
    origin_name: "Kathmandu",
    destination_name: "Pokhara",
    available_capacity_kg: 50,
    departure_offset_hours: 48,
  },
];

/**
 * Sample orders for testing order flows.
 */
export const ORDERS: OrderFixture[] = [
  {
    items: [
      { produce_name: "Fresh Tomatoes", quantity_kg: 5 },
      { produce_name: "Mountain Potatoes", quantity_kg: 10 },
    ],
    status: "pending",
  },
  {
    items: [{ produce_name: "Organic Rice", quantity_kg: 2 }],
    status: "delivered",
  },
];

/**
 * Rating fixtures for testing the rating flow.
 */
export const RATINGS = [
  { score: 5, comment: "Excellent quality produce!" },
  { score: 4, comment: "Good delivery, slightly late." },
  { score: 3, comment: "Average quality." },
];
