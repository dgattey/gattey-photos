import sharp from "sharp";
import { assertSessionToken } from "@/lib/auth";
import * as storage from "@/lib/storage";

export const runtime = "nodejs";

type Params = { params: Promise<{ id: string }> };

/** Clamp requested thumbnail width to sane bounds; `null` means serve the original. */
function parseWidth(url: string): number | null {
  const raw = new URL(url).searchParams.get("w");
  if (!raw) return null;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.min(Math.max(n, 64), 2048);
}

export async function GET(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  // Derive the blob path from the id (uploads always write `photos/{id}.jpg`). Avoids a manifest read
  // on every image request, which was the dominant Blob operation cost for grid loads. The original is
  // CDN-cached; resized variants are computed on demand and cached on each client's disk (no extra
  // Blob write/op per thumbnail).
  const { id } = await params;
  const bytes = await storage.readPhotoBytes(`photos/${id}.jpg`);
  if (!bytes) {
    return new Response("not found", { status: 404 });
  }

  const width = parseWidth(request.url);
  if (width != null) {
    const resized = await sharp(bytes)
      .rotate()
      .resize({ width, withoutEnlargement: true })
      .jpeg({ quality: 82 })
      .toBuffer();
    return imageResponse(resized, 86_400);
  }
  return imageResponse(bytes, 3_600);
}

function imageResponse(bytes: Buffer, maxAge: number): Response {
  return new Response(new Uint8Array(bytes), {
    headers: {
      "Content-Type": "image/jpeg",
      "Cache-Control": `private, max-age=${maxAge}`,
    },
  });
}
