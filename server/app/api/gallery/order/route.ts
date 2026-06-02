import { assertSessionToken } from "@/lib/auth";
import { jsonApiError } from "@/lib/api-error";
import { activeOrder, setOrder } from "@/lib/gallery";
import {
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";
import type { GalleryState, PhotoId } from "@/lib/types";

function orderApplied(state: GalleryState, requested: PhotoId[]): boolean {
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
    (state) => orderApplied(state, body.order!),
    { cacheControl: "no-store" }
  );
}
