import { v4 as uuid } from "uuid";
import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, storageErrorResponse } from "@/lib/api-error";
import { upsertPhoto } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { updateGalleryManifest } from "@/lib/gallery-manifest-update";
import * as storage from "@/lib/storage";

export async function POST(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  try {
    const form = await request.formData();
    const file = form.get("image");
    const filenameField = form.get("filename");
    if (!(file instanceof Blob)) {
      return jsonApiError(400, "image required");
    }

    const bytes = Buffer.from(await file.arrayBuffer());
    if (bytes.length === 0) {
      return jsonApiError(400, "empty image");
    }

    const uploadedByField = form.get("uploadedBy");
    const uploadedBy =
      typeof uploadedByField === "string" && uploadedByField.trim().length > 0
        ? uploadedByField.trim()
        : "Unknown";

    const id = uuid();
    const filename =
      typeof filenameField === "string" && filenameField.length > 0
        ? filenameField
        : `${id}.jpg`;
    const blobPath = `photos/${id}.jpg`;

    await storage.putPhotoBytes(blobPath, bytes);

    const now = new Date().toISOString();
    const entry = {
      id,
      filename,
      blobPath,
      sizeBytes: bytes.length,
      updatedAt: now,
      deletedAt: null,
      uploadedBy,
    };
    const saved = await updateGalleryManifest(
      (state) => upsertPhoto(state, entry),
      (state) => {
        const photo = state.photos[id];
        return photo != null && photo.deletedAt === null;
      }
    );
    const gallery = await buildGalleryResponse(request, saved);
    return Response.json(gallery, { status: 201 });
  } catch (err) {
    return storageErrorResponse(err, "[gallery upload]");
  }
}
