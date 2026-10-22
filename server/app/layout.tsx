import type { Metadata, Viewport } from "next";
import { brandCssVariables } from "@/lib/brand";
import { getSiteOrigin } from "@/lib/macos-release";
import { SITE_MEDIA } from "@/lib/site-media";
import "./globals.css";

const title = "Gattey Photos";
const description =
  "Download Gattey Photos for Mac. Upload family photos, schedule what each Bloomin8 frame shows, and keep every frame in sync.";
const ogImage = {
  url: SITE_MEDIA.shareIcon.src,
  width: SITE_MEDIA.shareIcon.width,
  height: SITE_MEDIA.shareIcon.height,
  alt: SITE_MEDIA.shareIcon.alt,
};

export const metadata: Metadata = {
  title,
  description,
  metadataBase: new URL(getSiteOrigin()),
  openGraph: {
    title,
    description,
    url: "/",
    siteName: title,
    type: "website",
    images: [ogImage],
  },
  twitter: {
    card: "summary",
    title,
    description,
    images: [ogImage.url],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f2f2f0" },
    { media: "(prefers-color-scheme: dark)", color: "#141416" },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" style={brandCssVariables}>
      <head>
        <link rel="preload" href={SITE_MEDIA.framePhoto.src} as="image" />
      </head>
      <body>{children}</body>
    </html>
  );
}
