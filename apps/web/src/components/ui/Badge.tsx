import { type ReactNode } from "react";

type BadgeColor = "primary" | "secondary" | "accent";

interface BadgeProps {
  children: ReactNode;
  color?: BadgeColor;
  className?: string;
}

const colorStyles: Record<BadgeColor, string> = {
  primary: "bg-blue-100 text-blue-700",
  secondary: "bg-emerald-100 text-emerald-700",
  accent: "bg-amber-100 text-amber-700",
};

function Badge({ children, color = "primary", className = "" }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-medium ${colorStyles[color]} ${className}`}
    >
      {children}
    </span>
  );
}

export { Badge, type BadgeProps, type BadgeColor };
