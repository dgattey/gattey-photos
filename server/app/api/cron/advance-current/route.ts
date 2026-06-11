import { assertCronSecret } from "@/lib/auth";
import { advanceCurrentPhoto } from "@/lib/gallery";
import { pushCurrentPhotoToAllDevices } from "@/lib/bloomin8/push-gallery";
import * as storage from "@/lib/storage";

async function handleAdvance(request: Request) {
  const auth = assertCronSecret(request);
  if (auth) return auth;

  const before = await storage.readManifest();
  const after = advanceCurrentPhoto(before);
  const changed = after.currentPhotoId !== before.currentPhotoId;

  let devicePush = null;
  // Rotation writes only the tiny sync-token blob; the photo catalog and its version are untouched.
  if (changed) {
    await storage.writeCurrent({
      galleryVersion: before.updatedAt,
      currentPhotoId: after.currentPhotoId ?? null,
      currentPhotoUpdatedBy: "cron",
      updatedAt: new Date().toISOString(),
    });
    devicePush = await pushCurrentPhotoToAllDevices(after);
  }

  return Response.json({
    ok: true,
    advanced: changed,
    previousPhotoId: before.currentPhotoId ?? null,
    currentPhotoId: after.currentPhotoId ?? null,
    updatedAt: after.updatedAt,
    devicePush,
  });
}

export async function GET(request: Request) {
  return handleAdvance(request);
}

export async function POST(request: Request) {
  return handleAdvance(request);
}
