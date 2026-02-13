import dynamic from "next/dynamic";

export const LocationPicker = dynamic(
  () => import("./LocationPicker"),
  { ssr: false },
);

export const ProduceMap = dynamic(
  () => import("./ProduceMap"),
  { ssr: false },
);

export const TripRouteMap = dynamic(
  () => import("./TripRouteMap"),
  { ssr: false },
);

export const OrderTrackingMap = dynamic(
  () => import("./OrderTrackingMap"),
  { ssr: false },
);
