import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "JiriSewa — Farm to Consumer Marketplace",
  description:
    "Connecting Nepali farmers directly with consumers through community riders. Fresh produce, fair prices.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return children;
}
