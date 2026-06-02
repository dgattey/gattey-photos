import { v4 as uuid } from "uuid";
import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, storageErrorResponse } from "@/lib/api-error";
import { ensureUploaderId, uploaderIdForName, upsertPhoto } from "@/lib/gallery";
import type { PhotoEntry } from "@/lib/types";
import {
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";
import * as storage from "@/lib/storage";

export async function POST(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  try {
    const form = await request.formData();
    const file = form.get("image");
    const base = parseBaseUpdatedAt(
      typeof form.get("baseUpdatedAt") === "string" ? form.get("baseUpdatedAt") : null
    );
    if (base instanceof Response) return base;

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
      typeof form.get("filename") === "string" && String(form.get("filename")).length > 0
        ? String(form.get("filename"))
        : `${id}.jpg`;
    const blobPath = `photos/${id}.jpg`;

    await storage.putPhotoBytes(blobPath, bytes);

    const now = new Date().toISOString();

    return respondGalleryMutation(
      request,
      "[gallery upload]",
      base,
      (state) => {
        const { state: withUploader, uploaderId } = ensureUploaderId(
          state,
          uploadedBy,
          uploaderIdForName(uploadedBy)
        );
        const entry: PhotoEntry = {
          id,
          filename,
          blobPath,
          sizeBytes: bytes.length,
          updatedAt: now,
          deletedAt: null,
          uploaderId,
        };
        return upsertPhoto(withUploader, entry);
      },
      { status: 201 }
    );
  } catch (err) {
    return storageErrorResponse(err, "[gallery upload]");
  }
}
