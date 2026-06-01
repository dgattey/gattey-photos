import { assertCronSecret } from "@/lib/auth";
import { advanceCurrentPhoto } from "@/lib/gallery";
import { commitManifest } from "@/lib/manifest-commit";
import * as storage from "@/lib/storage";

async function handleAdvance(request: Request) {
  const auth = assertCronSecret(request);
  if (auth) return auth;

  const before = await storage.readManifest();
  const after = advanceCurrentPhoto(before);
  const changed = after.version !== before.version;

  const saved = changed ? await commitManifest(after) : after;

  return Response.json({
    ok: true,
    advanced: changed,
    previousPhotoId: before.currentPhotoId ?? null,
    currentPhotoId: saved.currentPhotoId ?? null,
    version: saved.version,
  });
}

export async function GET(request: Request) {
  return handleAdvance(request);
}

export async function POST(request: Request) {
  return handleAdvance(request);
}
