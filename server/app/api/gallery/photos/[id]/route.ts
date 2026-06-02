import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, storageErrorResponse } from "@/lib/api-error";
import { canSoftDelete, softDelete } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { updateGalleryManifest } from "@/lib/gallery-manifest-update";
import * as storage from "@/lib/storage";

type Params = { params: Promise<{ id: string }> };

export async function DELETE(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const { id } = await params;
  const before = await storage.readManifest();
  if (!before.photos[id]) {
    return jsonApiError(404, "not found");
  }
  if (!canSoftDelete(before, id)) {
    return jsonApiError(400, "cannot delete last photo");
  }

  try {
    const saved = await updateGalleryManifest(
      (state) => softDelete(state, id) ?? state,
      (state) => state.photos[id]?.deletedAt != null
    );
    const gallery = await buildGalleryResponse(request, saved);
    return Response.json(gallery);
  } catch (err) {
    return storageErrorResponse(err, "[gallery delete]");
  }
}
