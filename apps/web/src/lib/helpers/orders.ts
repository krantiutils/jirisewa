import { OrderItemStatus } from "@jirisewa/shared";
import type {
  OrderItemWithDetails,
  FarmerItemGroup,
} from "@/lib/types/order";

/**
 * Group order items by farmer, computing per-group totals and pickup state.
 * Groups are sorted by pickup_sequence ascending.
 */
export function groupItemsByFarmer(
  items: OrderItemWithDetails[],
): FarmerItemGroup[] {
  const groups = new Map<string, FarmerItemGroup>();

  for (const item of items) {
    const farmerId = item.farmer_id;
    let group = groups.get(farmerId);

    if (!group) {
      group = {
        farmerId,
        farmerName: item.farmer?.name ?? "Unknown",
        farmerAvatar: item.farmer?.avatar_url ?? null,
        pickupSequence: item.pickup_sequence ?? 0,
        pickupStatus: item.pickup_status ?? OrderItemStatus.PendingPickup,
        pickupConfirmedAt: item.pickup_confirmed_at ?? null,
        items: [],
        subtotal: 0,
        totalKg: 0,
      };
      groups.set(farmerId, group);
    }

    group.items.push(item);
    group.subtotal += Number(item.subtotal);
    group.totalKg += Number(item.quantity_kg);
  }

  // Sort by pickup sequence
  return [...groups.values()].sort((a, b) => a.pickupSequence - b.pickupSequence);
}

/**
 * Reorder item availability result.
 */
export interface ReorderItemAvailability {
  listingId: string;
  farmerId: string;
  nameEn: string;
  nameNe: string;
  farmerName: string;
  photo: string | null;
  originalQtyKg: number;
  originalPricePerKg: number;
  currentPricePerKg: number | null;
  availableQtyKg: number | null;
  isActive: boolean;
  available: boolean;
}
