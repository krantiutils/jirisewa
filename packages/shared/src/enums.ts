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
  ConnectIPS = "connectips",
}

export enum PaymentStatus {
  Pending = "pending",
  Escrowed = "escrowed",
  Collected = "collected",
  Settled = "settled",
  Refunded = "refunded",
}

export enum VehicleType {
  Bike = "bike",
  Car = "car",
  Truck = "truck",
  Bus = "bus",
  Other = "other",
}

export enum RoleRated {
  Farmer = "farmer",
  Consumer = "consumer",
  Rider = "rider",
}

export enum NotificationCategory {
  OrderMatched = "order_matched",
  RiderPickedUp = "rider_picked_up",
  RiderArriving = "rider_arriving",
  OrderDelivered = "order_delivered",
  NewOrderForFarmer = "new_order_for_farmer",
  RiderArrivingForPickup = "rider_arriving_for_pickup",
  NewOrderMatch = "new_order_match",
  TripReminder = "trip_reminder",
  DeliveryConfirmed = "delivery_confirmed",
}

export enum DevicePlatform {
  Web = "web",
  Android = "android",
  Ios = "ios",
}

export enum OrderItemStatus {
  PendingPickup = "pending_pickup",
  PickedUp = "picked_up",
  Unavailable = "unavailable",
}

export enum PayoutStatus {
  Pending = "pending",
  Settled = "settled",
  Refunded = "refunded",
}

export enum PingStatus {
  Pending = "pending",
  Accepted = "accepted",
  Declined = "declined",
  Expired = "expired",
}
