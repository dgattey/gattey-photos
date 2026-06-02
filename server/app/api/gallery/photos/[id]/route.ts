import { assertSessionToken } from "@/lib/auth";
import { jsonApiError } from "@/lib/api-error";
import { canSoftDelete, softDelete } from "@/lib/gallery";
import {
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";
import * as storage from "@/lib/storage";

type Params = { params: Promise<{ id: string }> };

export async function DELETE(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const { id } = await params;
  let body: { baseUpdatedAt?: unknown };
  try {
    body = (await request.json()) as { baseUpdatedAt?: unknown };
  } catch {
    return jsonApiError(400, "JSON body with baseUpdatedAt required");
  }
  const base = parseBaseUpdatedAt(body.baseUpdatedAt);
  if (base instanceof Response) return base;

  const before = await storage.readManifest();
  if (!before.photos[id]) {
    return jsonApiError(404, "not found");
  }
  if (!canSoftDelete(before, id)) {
    return jsonApiError(400, "cannot delete last photo");
  }

  return respondGalleryMutation(
    request,
    "[gallery delete]",
    base,
    (state) => softDelete(state, id) ?? state,
    (state) => state.photos[id]?.deletedAt != null
  );
}
