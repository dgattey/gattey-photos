import { assertSessionToken } from "@/lib/auth";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const result = await storage.readManifestIfModified(
    request.headers.get("If-None-Match")
  );
  if (!result.modified) {
    return new Response(null, {
      status: 304,
      headers: { ETag: result.etag, "Cache-Control": "no-store" },
    });
  }
  return Response.json(buildGalleryResponse(result.state), {
    headers: { ETag: result.etag, "Cache-Control": "no-store" },
  });
}
