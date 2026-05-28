import { assertSyncPassword } from "@/lib/auth";
import * as storage from "@/lib/storage";

type Params = { params: Promise<{ id: string }> };

export async function GET(request: Request, { params }: Params) {
  const auth = await assertSyncPassword(request);
  if (auth) return auth;

  const { id } = await params;
  const state = await storage.readManifest();
  const entry = state.photos[id];
  if (!entry || entry.deletedAt) {
    return new Response("not found", { status: 404 });
  }
  const bytes = await storage.readPhotoBytes(entry.blobPath);
  if (!bytes) {
    return new Response("not found", { status: 404 });
  }
  return new Response(bytes, {
    headers: {
      "Content-Type": "image/jpeg",
      "Cache-Control": "private, max-age=3600",
    },
  });
}
