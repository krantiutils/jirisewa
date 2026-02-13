"use client";

import { forwardRef, type InputHTMLAttributes } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {}

const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className = "", ...props }, ref) => {
    return (
      <input
        ref={ref}
        className={`w-full bg-gray-100 text-foreground rounded-md px-4 h-14 border-2 border-transparent focus:bg-white focus:border-primary focus:outline-none transition-all duration-200 ${className}`}
        {...props}
      />
    );
  }
);

Input.displayName = "Input";

export { Input, type InputProps };
