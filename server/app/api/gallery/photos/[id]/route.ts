import { assertSessionToken } from "@/lib/auth";
import { softDelete } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import * as storage from "@/lib/storage";

type Params = { params: Promise<{ id: string }> };

export async function DELETE(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const { id } = await params;
  const state = await storage.readManifest();
  if (!state.photos[id]) {
    return new Response("not found", { status: 404 });
  }
  const next = softDelete(state, id);
  if (next === null) {
    return new Response("cannot delete last photo", { status: 400 });
  }
  const saved = await storage.writeManifest(next);
  const gallery = await buildGalleryResponse(request, saved);
  return Response.json(gallery);
}
