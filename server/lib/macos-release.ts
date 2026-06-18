import fs from "fs";
import path from "path";

export type MacOSRelease = {
  version: string;
  build: string;
  zipPath: string;
};

export function getMacOSRelease(): MacOSRelease | null {
  const appcastPath = path.join(process.cwd(), "public", "appcast.xml");
  if (!fs.existsSync(appcastPath)) return null;

  const xml = fs.readFileSync(appcastPath, "utf8");
  const version =
    xml.match(/<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/)?.[1] ??
    xml.match(/<title>([^<]+)<\/title>/)?.[1];
  const build = xml.match(/<sparkle:version>([^<]+)<\/sparkle:version>/)?.[1];
  const enclosure = xml.match(/<enclosure\s+url="([^"]+)"/)?.[1];

  if (!version || !enclosure) return null;

  let zipPath = enclosure;
  try {
    zipPath = new URL(enclosure).pathname;
  } catch {
    if (!zipPath.startsWith("/")) zipPath = `/${zipPath}`;
  }

  const zipFile = path.join(process.cwd(), "public", zipPath.replace(/^\//, ""));
  if (!fs.existsSync(zipFile)) return null;

  return {
    version,
    build: build ?? "",
    zipPath,
  };
}
