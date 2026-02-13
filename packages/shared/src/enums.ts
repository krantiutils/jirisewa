export enum UserRole {
  Farmer = "farmer",
  Consumer = "consumer",
  Rider = "rider",
}

export enum OrderStatus {
  Pending = "pending",
  Matched = "matched",
  PickedUp = "picked_up",
  InTransit = "in_transit",
  Delivered = "delivered",
  Cancelled = "cancelled",
  Disputed = "disputed",
}

export enum TripStatus {
  Scheduled = "scheduled",
  InTransit = "in_transit",
  Completed = "completed",
  Cancelled = "cancelled",
}

export enum PaymentMethod {
  Cash = "cash",
  ESewa = "esewa",
  Khalti = "khalti",
}

export enum PaymentStatus {
  Pending = "pending",
  Collected = "collected",
  Settled = "settled",
}

export enum VehicleType {
  Bike = "bike",
  Car = "car",
  Truck = "truck",
  Bus = "bus",
  Other = "other",
}
