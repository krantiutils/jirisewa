export interface CartItem {
  listingId: string;
  farmerId: string;
  quantityKg: number;
  pricePerKg: number;
  nameEn: string;
  nameNe: string;
  farmerName: string;
  photo: string | null;
}

export interface Cart {
  items: CartItem[];
}

export function getCartSubtotal(cart: Cart): number {
  return cart.items.reduce(
    (sum, item) => sum + item.quantityKg * item.pricePerKg,
    0,
  );
}

export function getCartTotalKg(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + item.quantityKg, 0);
}

export function getCartItemCount(cart: Cart): number {
  return cart.items.length;
}
