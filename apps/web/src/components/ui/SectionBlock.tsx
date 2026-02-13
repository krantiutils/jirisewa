import { forwardRef, type HTMLAttributes } from "react";

type SectionColor = "white" | "muted" | "primary" | "secondary" | "accent";

interface SectionBlockProps extends HTMLAttributes<HTMLElement> {
  color?: SectionColor;
  decoration?: boolean;
}

const colorStyles: Record<SectionColor, { bg: string; text: string; deco: string }> = {
  white: {
    bg: "bg-white",
    text: "text-foreground",
    deco: "bg-gray-200/20",
  },
  muted: {
    bg: "bg-muted",
    text: "text-foreground",
    deco: "bg-gray-300/30",
  },
  primary: {
    bg: "bg-primary",
    text: "text-white",
    deco: "bg-white/5",
  },
  secondary: {
    bg: "bg-secondary",
    text: "text-white",
    deco: "bg-white/5",
  },
  accent: {
    bg: "bg-accent",
    text: "text-foreground",
    deco: "bg-white/10",
  },
};

const SectionBlock = forwardRef<HTMLElement, SectionBlockProps>(
  ({ color = "white", decoration = false, className = "", children, ...props }, ref) => {
    const styles = colorStyles[color];

    return (
      <section
        ref={ref}
        className={`relative overflow-hidden py-16 px-4 sm:px-6 lg:px-8 ${styles.bg} ${styles.text} ${className}`}
        {...props}
      >
        {decoration && (
          <>
            <div
              className={`absolute -top-20 -right-20 h-64 w-64 rounded-full ${styles.deco}`}
              aria-hidden="true"
            />
            <div
              className={`absolute -bottom-16 -left-16 h-48 w-48 rotate-45 rounded-lg ${styles.deco}`}
              aria-hidden="true"
            />
          </>
        )}
        <div className="relative mx-auto max-w-7xl">{children}</div>
      </section>
    );
  }
);

SectionBlock.displayName = "SectionBlock";

export { SectionBlock, type SectionBlockProps, type SectionColor };
