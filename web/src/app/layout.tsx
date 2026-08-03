import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cycle Journal",
  description: "Journal, coach sessions, and tasks for Cycle Journal."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
