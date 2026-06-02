import { assertCronSecret } from "@/lib/auth";
import { advanceCurrentPhoto } from "@/lib/gallery";
import { applyGalleryMutation } from "@/lib/gallery-mutation";
import { pushCurrentPhotoToAllDevices } from "@/lib/bloomin8/push-gallery";
import * as storage from "@/lib/storage";

async function handleAdvance(request: Request) {
  const auth = assertCronSecret(request);
  if (auth) return auth;

  const before = await storage.readManifest();
  const after = advanceCurrentPhoto(before);
  const changed = after.currentPhotoId !== before.currentPhotoId;

  const saved = changed
    ? await applyGalleryMutation(before.updatedAt, () => after)
    : before;

  if (changed) {
    await pushCurrentPhotoToAllDevices(saved);
  }

  return Response.json({
    ok: true,
    advanced: changed,
    previousPhotoId: before.currentPhotoId ?? null,
    currentPhotoId: saved.currentPhotoId ?? null,
    updatedAt: saved.updatedAt,
  });
}

export async function GET(request: Request) {
  return handleAdvance(request);
}

export async function POST(request: Request) {
  return handleAdvance(request);
}
