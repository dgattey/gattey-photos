import type { NextConfig } from "next";

/** Icon URLs dyl-kit and dylangattey.com fetch cross-origin from every <app>.gattey.com site. */
const SHARED_ICON_PATHS = ["/icon.png", "/apple-touch-icon.png"] as const;

const SHARED_ICON_HEADERS = [
  { key: "Cache-Control", value: "public, max-age=3600, stale-while-revalidate=86400" },
  { key: "Access-Control-Allow-Origin", value: "*" },
];

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      bodySizeLimit: "12mb",
    },
  },
  async headers() {
    return SHARED_ICON_PATHS.map((source) => ({ source, headers: SHARED_ICON_HEADERS }));
  },
};

export default nextConfig;
