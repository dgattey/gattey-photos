import { assertSessionToken } from "@/lib/auth";
import { loadGallery } from "@/lib/gallery-service";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;
  const gallery = await loadGallery(request);
  return Response.json(gallery, {
    headers: { "Cache-Control": "no-store" },
  });
}
