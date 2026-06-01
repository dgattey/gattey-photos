import { v4 as uuid } from "uuid";
import { assertSessionToken } from "@/lib/auth";
import { upsertPhoto } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";

export async function POST(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const form = await request.formData();
  const file = form.get("image");
  const filenameField = form.get("filename");
  if (!(file instanceof Blob)) {
    return new Response("image required", { status: 400 });
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  if (bytes.length === 0) {
    return new Response("empty image", { status: 400 });
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

  const state = await storage.readManifest();
  const now = new Date().toISOString();
  const next = upsertPhoto(state, {
    id,
    filename,
    blobPath,
    sizeBytes: bytes.length,
    updatedAt: now,
    deletedAt: null,
    uploadedBy,
  });
  const saved = await storage.writeManifest(next);
  const gallery = await buildGalleryResponse(request, saved);
  return Response.json(gallery, { status: 201 });
}
