import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Gattey Photos",
  description:
    "Download Gattey Photos for macOS — family gallery uploads and Bloomin8 frame sync.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <link rel="preload" href="/unlock-welcome.png" as="image" />
      </head>
      <body>{children}</body>
    </html>
  );
}
