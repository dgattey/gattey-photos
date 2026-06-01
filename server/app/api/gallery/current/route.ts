import { assertSessionToken } from "@/lib/auth";
import { setCurrentPhoto } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { commitManifest } from "@/lib/manifest-commit";
import * as storage from "@/lib/storage";
import type { PhotoId } from "@/lib/types";

export async function PUT(request: Request) {
  const auth = await assertSessionToken(request);
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
  const saved = await commitManifest(next);
  const gallery = await buildGalleryResponse(request, saved);
  return Response.json(gallery);
}
