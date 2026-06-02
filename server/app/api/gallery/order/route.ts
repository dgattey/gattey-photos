import { assertSessionToken } from "@/lib/auth";
import { jsonApiError, storageErrorResponse } from "@/lib/api-error";
import { activeOrder, setOrder } from "@/lib/gallery";
import { buildGalleryResponse } from "@/lib/gallery-service";
import { updateGalleryManifest } from "@/lib/gallery-manifest-update";
import type { GalleryState, PhotoId } from "@/lib/types";

function activeOrderMatchesRequest(state: GalleryState, requested: PhotoId[]): boolean {
  const active = activeOrder(state);
  const activeSet = new Set(active);
  const filtered = requested.filter((id) => activeSet.has(id));
  const missing = active.filter((id) => !filtered.includes(id));
  const expected = [...filtered, ...missing];
  return active.length === expected.length && active.every((id, i) => id === expected[i]);
}

export async function PUT(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as { order?: PhotoId[] };
  if (!Array.isArray(body.order)) {
    return jsonApiError(400, "order array required");
  }

  try {
    const saved = await updateGalleryManifest(
      (state) => setOrder(state, body.order!),
      (state) => activeOrderMatchesRequest(state, body.order!)
    );
    const gallery = await buildGalleryResponse(request, saved);
    return Response.json(gallery, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (err) {
    return storageErrorResponse(err, "[gallery order]");
  }
}
