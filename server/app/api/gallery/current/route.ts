import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, storageErrorResponse } from "@/lib/api-error";
import { setCurrentPhoto } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { pushCurrentPhotoToAllDevices } from "@/lib/bloomin8/push-gallery";
import * as storage from "@/lib/storage";
import type { PhotoId } from "@/lib/types";

/** Cheap poll: only the currently shown photo, so clients catch cron rotations without a full pull. */
export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;
  const current = await storage.readCurrent();
  return Response.json(current, { headers: { "Cache-Control": "no-store" } });
}

/**
 * Set the shown photo. Writes only `current.json` (last-write-wins with the cron), so it never
 * rewrites the photo catalog or bumps its version.
 */
export async function PUT(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as { photoId?: PhotoId };
  if (!body.photoId || typeof body.photoId !== "string") {
    return jsonApiError(400, "photoId required");
  }

  try {
    const state = await storage.readManifest();
    const next = setCurrentPhoto(state, body.photoId);
    if (next.currentPhotoId !== body.photoId) {
      return jsonApiError(400, "photo not active");
    }
    await storage.writeCurrent({
      currentPhotoId: next.currentPhotoId ?? null,
      currentPhotoUpdatedBy: "manual",
      updatedAt: new Date().toISOString(),
    });
    await pushCurrentPhotoToAllDevices(next);
    return Response.json(buildGalleryResponse(next));
  } catch (err) {
    return storageErrorResponse(err, "[gallery current]");
  }
}
