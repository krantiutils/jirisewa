import { type LucideIcon } from "lucide-react";

type IconCircleColor = "primary" | "secondary" | "accent";

interface IconCircleProps {
  icon: LucideIcon;
  color?: IconCircleColor;
  className?: string;
}

const colorStyles: Record<IconCircleColor, string> = {
  primary: "bg-white text-blue-600",
  secondary: "bg-white text-emerald-600",
  accent: "bg-white text-amber-600",
};

function IconCircle({ icon: Icon, color = "primary", className = "" }: IconCircleProps) {
  return (
    <div
      className={`inline-flex h-14 w-14 items-center justify-center rounded-full transition-transform duration-200 group-hover:scale-110 ${colorStyles[color]} ${className}`}
    >
      <Icon className="h-7 w-7" strokeWidth={2.25} />
    </div>
  );
}

export { IconCircle, type IconCircleProps, type IconCircleColor };
