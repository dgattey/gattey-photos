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

  const { id } = await params;
  const state = await storage.readManifest();
  const entry = state.photos[id];
  if (!entry || entry.deletedAt) {
    return new Response("not found", { status: 404 });
  }
  const bytes = await storage.readPhotoBytes(entry.blobPath);
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
    return new Response(new Uint8Array(resized), {
      headers: {
        "Content-Type": "image/jpeg",
        // Variant keyed by id+width; a given id maps to one immutable photo, so cache it longer.
        "Cache-Control": "private, max-age=86400",
      },
    });
  }

  return new Response(new Uint8Array(bytes), {
    headers: {
      "Content-Type": "image/jpeg",
      "Cache-Control": "private, max-age=3600",
    },
  });
}
