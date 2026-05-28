import { assertSyncPassword } from "@/lib/auth";
import { loadGallery } from "@/lib/gallery-service";

export async function GET(request: Request) {
  const auth = await assertSyncPassword(request);
  if (auth) return auth;
  const gallery = await loadGallery(request);
  return Response.json(gallery);
}
