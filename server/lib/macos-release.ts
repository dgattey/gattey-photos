import fs from "fs";
import path from "path";
import { unstable_noStore as noStore } from "next/cache";

export type MacOSRelease = {
  version: string;
  build: string;
  /** Pathname for the zip, e.g. `/Gattey-Photos-1.0.7.zip`. */
  zipPath: string;
  /** Absolute URL used for download redirects. */
  downloadUrl: string;
  /** False when appcast names a zip that is not on the site yet (release still deploying). */
  downloadReady: boolean;
};

export function parseAppcastXml(xml: string): Omit<MacOSRelease, "downloadReady"> | null {
  const version =
    xml.match(/<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/)?.[1] ??
    xml.match(/<title>([^<]+)<\/title>/)?.[1];
  const build = xml.match(/<sparkle:version>([^<]+)<\/sparkle:version>/)?.[1] ?? "";
  const enclosure = xml.match(/<enclosure\s+url="([^"]+)"/)?.[1];
  if (!version || !enclosure) return null;

  let downloadUrl = enclosure;
  let zipPath: string;
  try {
    const url = new URL(enclosure);
    downloadUrl = url.href;
    zipPath = url.pathname;
  } catch {
    zipPath = enclosure.startsWith("/") ? enclosure : `/${enclosure}`;
    downloadUrl = `${getSiteOrigin()}${zipPath}`;
  }

  return { version, build, zipPath, downloadUrl };
}

export function getSiteOrigin(): string {
  if (process.env.GATTEY_SITE_ORIGIN) {
    return process.env.GATTEY_SITE_ORIGIN.replace(/\/$/, "");
  }
  if (process.env.VERCEL_ENV === "production") {
    return "https://photos.gattey.com";
  }
  if (process.env.VERCEL_URL) {
    return `https://${process.env.VERCEL_URL}`;
  }
  return `http://localhost:${process.env.PORT ?? 3000}`;
}

async function readAppcastXml(): Promise<string | null> {
  const origin = getSiteOrigin();
  try {
    const res = await fetch(`${origin}/appcast.xml`, {
      cache: "no-store",
      next: { revalidate: 0 },
    });
    if (res.ok) return await res.text();
  } catch {
    // Local dev or fetch failure — use the bundled file from this deployment.
  }

  const appcastPath = path.join(process.cwd(), "public", "appcast.xml");
  if (!fs.existsSync(appcastPath)) return null;
  return fs.readFileSync(appcastPath, "utf8");
}

async function zipIsAvailable(downloadUrl: string, zipPath: string): Promise<boolean> {
  try {
    const res = await fetch(downloadUrl, { method: "HEAD", cache: "no-store" });
    if (res.ok) return true;
  } catch {
    // fall through to local public/
  }

  const localZip = path.join(process.cwd(), "public", zipPath.replace(/^\//, ""));
  return fs.existsSync(localZip);
}

/** Reads the live appcast on each request (not statically baked at build time). */
export async function getMacOSRelease(): Promise<MacOSRelease | null> {
  noStore();

  const xml = await readAppcastXml();
  if (!xml) return null;

  const parsed = parseAppcastXml(xml);
  if (!parsed) return null;

  const downloadReady = await zipIsAvailable(parsed.downloadUrl, parsed.zipPath);
  return { ...parsed, downloadReady };
}
