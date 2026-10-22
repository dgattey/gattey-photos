import fs from "fs";
import path from "path";

export type ReleaseNoteSection = {
  version: string;
  notes: string[];
};

export type MacOSRelease = {
  version: string;
  build: string;
  /** From `sparkle:minimumSystemVersion`, e.g. `14.0`. */
  minimumSystemVersion: string | null;
  /** Newest first, as plain text, from the cumulative HTML in the latest item's `<description>`. */
  releaseNotes: ReleaseNoteSection[];
  /** Pathname for the zip, e.g. `/Gattey-Photos-1.0.7.zip`. */
  zipPath: string;
  /** Absolute URL used for download redirects. */
  downloadUrl: string;
  /** False when appcast names a zip that is not in `server/public/` (broken tree or mid-release build). */
  downloadReady: boolean;
};

export function parseAppcastXml(xml: string): Omit<MacOSRelease, "downloadReady"> | null {
  const version =
    xml.match(/<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/)?.[1] ??
    xml.match(/<title>([^<]+)<\/title>/)?.[1];
  const build = xml.match(/<sparkle:version>([^<]+)<\/sparkle:version>/)?.[1] ?? "";
  const minimumSystemVersion =
    xml.match(/<sparkle:minimumSystemVersion>([^<]+)<\/sparkle:minimumSystemVersion>/)?.[1] ??
    null;
  const descriptionHtml =
    xml.match(/<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>/)?.[1] ?? "";
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

  return {
    version,
    build,
    minimumSystemVersion,
    releaseNotes: parseReleaseNotesHtml(descriptionHtml),
    zipPath,
    downloadUrl,
  };
}

const HTML_ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
};

function htmlToText(html: string): string {
  return html
    .replace(/<[^>]+>/g, "")
    .replace(/&(amp|lt|gt|quot|#39);/g, (entity) => HTML_ENTITIES[entity] ?? entity)
    .replace(/\s+/g, " ")
    .trim();
}

/** Splits `scripts/release-notes.sh` HTML (`<h3>version</h3><ul><li>…`) into sections. */
export function parseReleaseNotesHtml(html: string): ReleaseNoteSection[] {
  return html
    .split(/<h3\b/)
    .slice(1)
    .map((chunk) => {
      const version = htmlToText(chunk.match(/^[^>]*>([\s\S]*?)<\/h3>/)?.[1] ?? "");
      const notes = [...chunk.matchAll(/<li\b[^>]*>([\s\S]*?)<\/li>/g)]
        .map((match) => htmlToText(match[1]))
        .filter(Boolean);
      return { version, notes };
    })
    .filter((section) => section.version && section.notes.length > 0);
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

function readBundledAppcastXml(): string | null {
  const appcastPath = path.join(process.cwd(), "public", "appcast.xml");
  if (!fs.existsSync(appcastPath)) return null;
  return fs.readFileSync(appcastPath, "utf8");
}

function zipExistsInPublic(zipPath: string): boolean {
  const localZip = path.join(process.cwd(), "public", zipPath.replace(/^\//, ""));
  return fs.existsSync(localZip);
}

/** Reads committed `server/public/` artifacts (static at build / deploy time). */
export function getMacOSRelease(): MacOSRelease | null {
  const xml = readBundledAppcastXml();
  if (!xml) return null;

  const parsed = parseAppcastXml(xml);
  if (!parsed) return null;

  const downloadReady = zipExistsInPublic(parsed.zipPath);
  return { ...parsed, downloadReady };
}
