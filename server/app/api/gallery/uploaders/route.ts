import { assertSessionToken } from "@/lib/auth";
import { jsonApiError } from "@/lib/api-error";
import { renameUploader } from "@/lib/gallery";
import {
  parseBaseUpdatedAt,
  respondGalleryMutation,
} from "@/lib/gallery-mutation";

export async function PATCH(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as {
    fromName?: string;
    toName?: string;
    baseUpdatedAt?: unknown;
  };
  const fromName =
    typeof body.fromName === "string" ? body.fromName.trim() : "";
  const toName = typeof body.toName === "string" ? body.toName.trim() : "";
  if (!fromName || !toName) {
    return jsonApiError(400, "fromName and toName required");
  }
  if (fromName === toName) {
    return jsonApiError(400, "fromName and toName must differ");
  }
  const base = parseBaseUpdatedAt(body.baseUpdatedAt);
  if (base instanceof Response) return base;

  return respondGalleryMutation(
    request,
    "[gallery uploaders]",
    base,
    (state) => renameUploader(state, fromName, toName),
    { cacheControl: "no-store" }
  );
}
