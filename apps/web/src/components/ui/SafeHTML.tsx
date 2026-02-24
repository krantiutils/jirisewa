"use client";

import { sanitizeHTML } from "@/lib/sanitize";

interface SafeHTMLProps {
  html: string;
  className?: string;
}

export function SafeHTML({ html, className }: SafeHTMLProps) {
  const clean = sanitizeHTML(html);

  return (
    <div
      className={`prose prose-sm max-w-none prose-headings:text-foreground prose-p:text-gray-700 prose-a:text-primary prose-a:no-underline hover:prose-a:underline prose-strong:text-foreground prose-blockquote:border-l-primary ${className ?? ""}`}
      dangerouslySetInnerHTML={{ __html: clean }}
    />
  );
}
