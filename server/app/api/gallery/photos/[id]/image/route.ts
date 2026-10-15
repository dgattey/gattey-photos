import sharp from "sharp";
import { assertSessionToken } from "@/lib/auth";
import * as storage from "@/lib/storage";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

const MAX_THUMBNAIL_CACHE_ENTRIES = 128;
const MAX_THUMBNAIL_CACHE_BYTES = 32 * 1024 * 1024;
const resizedThumbnailCache = new Map<string, Buffer>();
let resizedThumbnailCacheBytes = 0;

function getCachedThumbnail(key: string): Buffer | undefined {
  const hit = resizedThumbnailCache.get(key);
  if (!hit) return undefined;
  resizedThumbnailCache.delete(key);
  resizedThumbnailCache.set(key, hit);
  return hit;
}

function setCachedThumbnail(key: string, bytes: Buffer): void {
  if (bytes.byteLength > MAX_THUMBNAIL_CACHE_BYTES) return;
  const existing = resizedThumbnailCache.get(key);
  if (existing) {
    resizedThumbnailCacheBytes -= existing.byteLength;
    resizedThumbnailCache.delete(key);
  }
  while (
    resizedThumbnailCache.size >= MAX_THUMBNAIL_CACHE_ENTRIES ||
    resizedThumbnailCacheBytes + bytes.byteLength > MAX_THUMBNAIL_CACHE_BYTES
  ) {
    const oldestKey = resizedThumbnailCache.keys().next().value;
    if (oldestKey === undefined) break;
    const oldest = resizedThumbnailCache.get(oldestKey);
    resizedThumbnailCache.delete(oldestKey);
    if (oldest) resizedThumbnailCacheBytes -= oldest.byteLength;
  }
  resizedThumbnailCache.set(key, bytes);
  resizedThumbnailCacheBytes += bytes.byteLength;
}

/** Clamp requested thumbnail width to sane bounds; `null` means serve the original. */
function parseWidth(url: string): number | null {
  const raw = new URL(url).searchParams.get("w");
  if (!raw) return null;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.min(Math.max(n, 64), 2048);
}

function makeImageETag(id: string, width: number | null): string {
  return width != null ? `"photo-${id}-w${width}"` : `"photo-${id}"`;
}

export async function GET(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const { id } = await params;
  const width = parseWidth(request.url);
  const etag = makeImageETag(id, width);

  if (request.headers.get("If-None-Match") === etag) {
    return new Response(null, {
      status: 304,
      headers: {
        ETag: etag,
        "Cache-Control": `private, max-age=${width != null ? 86_400 : 3_600}, immutable`,
      },
    });
  }

  if (width != null) {
    const cacheKey = `${id}:w${width}`;
    const cached = getCachedThumbnail(cacheKey);
    if (cached) {
      return imageResponse(cached, 86_400, etag);
    }
    const bytes = await storage.readPhotoBytes(`photos/${id}.jpg`);
    if (!bytes) {
      return new Response("not found", { status: 404 });
    }
    const resized = await sharp(bytes)
      .rotate()
      .resize({ width, withoutEnlargement: true })
      .jpeg({ quality: 82 })
      .toBuffer();
    setCachedThumbnail(cacheKey, resized);
    return imageResponse(resized, 86_400, etag);
  }

  const bytes = await storage.readPhotoBytes(`photos/${id}.jpg`);
  if (!bytes) {
    return new Response("not found", { status: 404 });
  }
  return imageResponse(bytes, 3_600, etag);
}

function imageResponse(bytes: Buffer, maxAge: number, etag: string): Response {
  return new Response(new Uint8Array(bytes), {
    headers: {
      "Content-Type": "image/jpeg",
      "Cache-Control": `private, max-age=${maxAge}, immutable`,
      ETag: etag,
    },
  });
}
