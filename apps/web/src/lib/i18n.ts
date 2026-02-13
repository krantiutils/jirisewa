export const locales = ["en", "ne"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "ne";

export function isValidLocale(lang: string): lang is Locale {
  return locales.includes(lang as Locale);
}
