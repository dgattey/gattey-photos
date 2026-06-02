import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { storageErrorResponse } from "./api-error";
import { ManifestUpdateConflictError } from "./manifest-errors";

describe("storageErrorResponse", () => {
  it("maps missing blob credentials to 503 with setup hint", async () => {
    const res = storageErrorResponse(
      new Error(
        "Vercel Blob: No blob credentials found. Pass BLOB_READ_WRITE_TOKEN"
      ),
      "[test]"
    );
    assert.equal(res.status, 503);
    const body = (await res.json()) as { error: string };
    assert.match(body.error, /BLOB_READ_WRITE_TOKEN/);
  });

  it("maps BlobAccessError to access hint", async () => {
    const err = new Error("");
    err.name = "BlobAccessError";
    const res = storageErrorResponse(err, "[test]");
    assert.equal(res.status, 503);
    const body = (await res.json()) as { error: string };
    assert.match(body.error, /GATTEY_BLOB_ACCESS|access rejected/i);
  });

  it("maps manifest update conflicts to 503", async () => {
    const res = storageErrorResponse(
      new ManifestUpdateConflictError(),
      "[test]"
    );
    assert.equal(res.status, 503);
    const body = (await res.json()) as { error: string };
    assert.match(body.error, /retry upload/i);
  });
});
