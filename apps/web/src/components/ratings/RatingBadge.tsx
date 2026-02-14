import { Star } from "lucide-react";

interface RatingBadgeProps {
  avgRating: number;
  count: number;
  showCount?: boolean;
  size?: "sm" | "md";
}

const sizeClasses = {
  sm: { star: "h-3.5 w-3.5", text: "text-sm" },
  md: { star: "h-4 w-4", text: "text-sm" },
};

export function RatingBadge({
  avgRating,
  count,
  showCount = true,
  size = "sm",
}: RatingBadgeProps) {
  if (avgRating <= 0 || count <= 0) return null;

  const classes = sizeClasses[size];

  return (
    <span className={`inline-flex items-center gap-0.5 ${classes.text} text-gray-600`}>
      <Star className={`${classes.star} fill-amber-400 text-amber-400`} />
      <span>{Number(avgRating).toFixed(1)}</span>
      {showCount && <span>({count})</span>}
    </span>
  );
}
