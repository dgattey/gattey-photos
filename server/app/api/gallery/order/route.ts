import { assertSyncPassword } from "@/lib/auth";
import { setOrder } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";
import type { PhotoId } from "@/lib/types";

export async function PUT(request: Request) {
  const auth = await assertSyncPassword(request);
  if (auth) return auth;

  const body = (await request.json()) as { order?: PhotoId[] };
  if (!Array.isArray(body.order)) {
    return new Response("order array required", { status: 400 });
  }

  const state = await storage.readManifest();
  const next = setOrder(state, body.order);
  const saved = await storage.writeManifest(next);
  const gallery = await buildGalleryResponse(request, saved);
  return Response.json(gallery);
}
