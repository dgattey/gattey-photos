import { assertSyncPassword } from "@/lib/auth";
import { setCurrentPhoto } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";
import type { PhotoId } from "@/lib/types";

export async function PUT(request: Request) {
  const auth = await assertSyncPassword(request);
  if (auth) return auth;

  const body = (await request.json()) as { photoId?: PhotoId };
  if (!body.photoId || typeof body.photoId !== "string") {
    return new Response("photoId required", { status: 400 });
  }

  const state = await storage.readManifest();
  const next = setCurrentPhoto(state, body.photoId);
  if (next.currentPhotoId !== body.photoId) {
    return new Response("photo not active", { status: 400 });
  }
  await storage.writeManifest(next);
  const gallery = await buildGalleryResponse(request, next);
  return Response.json(gallery);
}
