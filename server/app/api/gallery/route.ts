import { assertSessionToken } from "@/lib/auth";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  // Cheap path: a matching ETag (the common periodic case) reads only the catalog version (one op).
  const etag = `"${await storage.readGalleryVersion()}"`;
  if (request.headers.get("If-None-Match") === etag) {
    return new Response(null, {
      status: 304,
      headers: { ETag: etag, "Cache-Control": "no-store" },
    });
  }
  const state = await storage.readManifest();
  return Response.json(buildGalleryResponse(state), {
    headers: { ETag: `"${state.updatedAt}"`, "Cache-Control": "no-store" },
  });
}
