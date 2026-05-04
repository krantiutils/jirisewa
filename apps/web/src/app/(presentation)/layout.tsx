import "../globals.css";
import "./presentation.css";
import { Outfit, Mukta } from "next/font/google";
import type { Metadata } from "next";

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
});

const mukta = Mukta({
  variable: "--font-mukta",
  subsets: ["devanagari", "latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "JiriSewa — Presentation",
  description: "जिरीदेखि सुरु, नेपालभर पुग्ने — Jiri Nagarpalika presentation",
  robots: { index: false, follow: false },
};

export default function PresentationLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ne" className={`${outfit.variable} ${mukta.variable}`}>
      <body className="font-sans bg-foreground text-foreground antialiased">
        {children}
      </body>
    </html>
  );
}
