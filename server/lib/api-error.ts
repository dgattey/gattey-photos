/** JSON error body for sync clients (macOS `SyncHTTPFailure` reads `error` / `message`). */
export function jsonApiError(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

function blobMisconfiguredMessage(): string {
  return "Blob storage misconfigured: link Vercel Blob on the project or set BLOB_READ_WRITE_TOKEN";
}

function blobAccessHint(): string {
  const mode = process.env.GATTEY_BLOB_ACCESS?.trim().toLowerCase();
  if (mode === "public") {
    return "Blob access rejected: store may be private — remove GATTEY_BLOB_ACCESS or set it to private";
  }
  return "Blob access rejected: set GATTEY_BLOB_ACCESS=public only if the Vercel Blob store is public";
}

import { buildGalleryResponse } from "./gallery-service";
import { StaleGalleryError } from "./manifest-errors";

/** Map storage / Blob SDK failures to HTTP status + client-visible message. */
export function staleGalleryResponse(
  request: Request,
  err: StaleGalleryError
): Response {
  void request;
  const gallery = buildGalleryResponse(err.state);
  return Response.json(
    { error: "gallery stale", ...gallery },
    { status: 409, headers: { "Cache-Control": "no-store" } }
  );
}

export function storageErrorResponse(
  err: unknown,
  logPrefix: string
): Response {
  const name = err instanceof Error ? err.name : "";
  const message =
    err instanceof Error && err.message.trim().length > 0
      ? err.message
      : "storage operation failed";
  console.error(logPrefix, name || message, err);

  const lower = message.toLowerCase();

  if (
    lower.includes("no blob credentials") ||
    lower.includes("blob_read_write_token") ||
    name === "BlobStoreNotFoundError"
  ) {
    return jsonApiError(503, blobMisconfiguredMessage());
  }

  if (name === "BlobAccessError" || (lower.includes("access") && lower.includes("blob"))) {
    return jsonApiError(503, blobAccessHint());
  }

  if (name === "BlobFileTooLargeError" || lower.includes("too large")) {
    return jsonApiError(413, message);
  }

  if (name === "BlobServiceRateLimited" || lower.includes("rate limit")) {
    return jsonApiError(429, "Blob storage rate limited; retry shortly");
  }

  return jsonApiError(500, message);
}
