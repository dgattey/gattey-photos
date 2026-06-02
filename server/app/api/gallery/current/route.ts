import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, staleGalleryResponse, storageErrorResponse } from "@/lib/api-error";
import { setCurrentPhoto } from "@/lib/gallery";
import { applyGalleryMutation, parseBaseUpdatedAt } from "@/lib/gallery-mutation";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { pushCurrentPhotoToAllDevices } from "@/lib/bloomin8/push-gallery";
import { StaleGalleryError } from "@/lib/manifest-errors";
import type { PhotoId } from "@/lib/types";

export async function PUT(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as {
    photoId?: PhotoId;
    baseUpdatedAt?: unknown;
  };
  if (!body.photoId || typeof body.photoId !== "string") {
    return jsonApiError(400, "photoId required");
  }
  const base = parseBaseUpdatedAt(body.baseUpdatedAt);
  if (base instanceof Response) return base;

  try {
    const saved = await applyGalleryMutation(
      base,
      (state) => setCurrentPhoto(state, body.photoId!),
      (state) => state.currentPhotoId === body.photoId
    );
    if (saved.currentPhotoId !== body.photoId) {
      return jsonApiError(400, "photo not active");
    }
    await pushCurrentPhotoToAllDevices(saved);
    const gallery = await buildGalleryResponse(request, saved);
    return Response.json(gallery);
  } catch (err) {
    if (err instanceof StaleGalleryError) {
      return staleGalleryResponse(request, err);
    }
    return storageErrorResponse(err, "[gallery current]");
  }
}
