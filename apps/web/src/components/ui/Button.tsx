"use client";

import { forwardRef, type ButtonHTMLAttributes } from "react";

type ButtonVariant = "primary" | "secondary" | "outline";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    "bg-primary text-white hover:bg-blue-600 hover:scale-105 focus:ring-primary",
  secondary:
    "bg-muted text-foreground hover:bg-gray-200 hover:scale-105 focus:ring-gray-400",
  outline:
    "border-4 border-primary text-primary bg-transparent hover:bg-primary hover:text-white hover:scale-105 focus:ring-primary",
};

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = "primary", className = "", children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={`inline-flex items-center justify-center font-semibold rounded-md h-14 px-8 transition-all duration-200 cursor-pointer focus:outline-none focus:ring-2 focus:ring-offset-2 ${variantStyles[variant]} ${className}`}
        {...props}
      >
        {children}
      </button>
    );
  }
);

Button.displayName = "Button";

export { Button, type ButtonProps, type ButtonVariant };
