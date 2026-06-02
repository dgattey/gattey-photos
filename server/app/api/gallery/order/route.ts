import { assertSessionToken } from "@/lib/auth";
import { jsonApiError } from "@/lib/api-error";
import { setOrder } from "@/lib/gallery";
import {
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";
import type { PhotoId } from "@/lib/types";

export async function PUT(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as {
    order?: PhotoId[];
    baseUpdatedAt?: unknown;
  };
  if (!Array.isArray(body.order)) {
    return jsonApiError(400, "order array required");
  }
  const base = parseBaseUpdatedAt(body.baseUpdatedAt);
  if (base instanceof Response) return base;

  return respondGalleryMutation(
    request,
    "[gallery order]",
    base,
    (state) => setOrder(state, body.order!),
    { cacheControl: "no-store" }
  );
}
