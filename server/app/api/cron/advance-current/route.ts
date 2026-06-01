import { assertCronSecret } from "@/lib/auth";
import { advanceCurrentPhoto } from "@/lib/gallery";
import * as storage from "@/lib/storage";

async function handleAdvance(request: Request) {
  const auth = assertCronSecret(request);
  if (auth) return auth;

  const before = await storage.readManifest();
  const after = advanceCurrentPhoto(before);
  const changed = after.version !== before.version;

  if (changed) {
    await storage.writeManifest(after);
  }

  return Response.json({
    ok: true,
    advanced: changed,
    previousPhotoId: before.currentPhotoId ?? null,
    currentPhotoId: after.currentPhotoId ?? null,
    version: after.version,
  });
}

export async function GET(request: Request) {
  return handleAdvance(request);
}

export async function POST(request: Request) {
  return handleAdvance(request);
}
