import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@dylkit/web"],
  // @dylkit/web's loadSite() reads DylApp.toml (outside this project) and the screenshots' PNG headers at request
  // time, and Vercel leaves both out of function bundles unless they're traced.
  outputFileTracingRoot: path.join(import.meta.dirname, ".."),
  outputFileTracingIncludes: { "/**": ["../DylApp.toml", "./public/*.png"] },
  experimental: {
    serverActions: {
      bodySizeLimit: "12mb",
    },
  },
};

export default nextConfig;
