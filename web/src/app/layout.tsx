import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://cycle-web-prod-1031235624127.asia-northeast1.run.app"),
  title: "Cycle — 自分と向き合う日記",
  description: "日々を記録し、振り返り、次の一歩を見つけるためのジャーナル。",
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "ja_JP",
    url: "/",
    siteName: "Cycle",
    title: "Cycle — 自分と向き合う日記",
    description: "日々を記録し、振り返り、次の一歩を見つけるためのジャーナル。"
  },
  icons: {
    icon: "/cycle-icon.png",
    apple: "/cycle-icon.png"
  },
  robots: { index: true, follow: true }
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
