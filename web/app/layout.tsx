import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KnowBody — Calm, guided fitness in your pocket",
  description:
    "Snap a meal, let AI count Thai-food calories, do one-tap workouts, and raise Mochi. Fitness for people who don't like tracking. Thai-first.",
  openGraph: {
    title: "KnowBody",
    description: "Know your body without obsessing over numbers.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
