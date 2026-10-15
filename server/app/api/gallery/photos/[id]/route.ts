import { assertSessionToken } from "@/lib/auth";
import { jsonApiError } from "@/lib/api-error";
import { canSoftDelete, softDelete } from "@/lib/gallery";
import {
  GalleryMutationError,
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";

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

  return respondGalleryMutation(request, "[gallery delete]", base, (state) => {
    if (!state.photos[id]) {
      throw new GalleryMutationError(404, "not found");
    }
    if (!canSoftDelete(state, id)) {
      throw new GalleryMutationError(400, "cannot delete last photo");
    }
    return softDelete(state, id) ?? state;
  });
}
