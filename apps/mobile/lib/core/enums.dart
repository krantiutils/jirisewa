// Application enums matching the database enum types.

enum UserRole {
  farmer,
  consumer,
  rider;

  String get label {
    switch (this) {
      case UserRole.farmer:
        return 'Farmer';
      case UserRole.consumer:
        return 'Consumer';
      case UserRole.rider:
        return 'Rider';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.consumer,
    );
  }
}

enum OrderStatus {
  pending,
  matched,
  pickedUp,
  inTransit,
  delivered,
  cancelled,
  disputed;

  String get dbValue {
    switch (this) {
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.inTransit:
        return 'in_transit';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.matched:
        return 'Matched';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.disputed:
        return 'Disputed';
    }
  }

  static OrderStatus fromDb(String value) {
    switch (value) {
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'in_transit':
        return OrderStatus.inTransit;
      default:
        return OrderStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => OrderStatus.pending,
        );
    }
  }

  bool get isActive =>
      this == pending || this == matched || this == pickedUp || this == inTransit;
}

enum TripStatus {
  scheduled,
  inTransit,
  completed,
  cancelled;

  String get dbValue {
    switch (this) {
      case TripStatus.inTransit:
        return 'in_transit';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case TripStatus.scheduled:
        return 'Scheduled';
      case TripStatus.inTransit:
        return 'In Transit';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  static TripStatus fromDb(String value) {
    switch (value) {
      case 'in_transit':
        return TripStatus.inTransit;
      default:
        return TripStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => TripStatus.scheduled,
        );
    }
  }

  bool get isActive => this == scheduled || this == inTransit;
}

enum PaymentMethod {
  cash,
  esewa,
  khalti;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash on Delivery';
      case PaymentMethod.esewa:
        return 'eSewa';
      case PaymentMethod.khalti:
        return 'Khalti';
    }
  }

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum PaymentStatus {
  pending,
  escrowed,
  collected,
  settled,
  refunded;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

enum VehicleType {
  bike,
  car,
  truck,
  bus,
  other;

  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }

  static VehicleType fromString(String value) {
    return VehicleType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VehicleType.other,
    );
  }
}
