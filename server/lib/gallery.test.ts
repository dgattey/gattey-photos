import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { renameUploader, renameUploaderApplied } from "./gallery.ts";
import { emptyGalleryUpdatedAt, touchGallery } from "./gallery-mutation.ts";
import type { GalleryState } from "./types.ts";

function photo(id: string, uploadedBy: string) {
  return {
    id,
    filename: `${id}.jpg`,
    blobPath: `photos/${id}.jpg`,
    sizeBytes: 1,
    updatedAt: "2020-01-01T00:00:00.000Z",
    deletedAt: null,
    uploadedBy,
  };
}

describe("renameUploader", () => {
  const base: GalleryState = {
    updatedAt: "2024-01-01T00:00:00.000Z",
    order: ["a", "b"],
    photos: {
      a: photo("a", "Alex"),
      b: photo("b", "Sam"),
    },
    currentPhotoId: "a",
  };

  it("updates matching entries", () => {
    const next = renameUploader(base, "Alex", "Alexander");
    assert.equal(next.photos.a!.uploadedBy, "Alexander");
    assert.equal(next.photos.b!.uploadedBy, "Sam");
    assert.equal(next.updatedAt, base.updatedAt);
  });

  it("is a no-op when names match or empty", () => {
    assert.equal(renameUploader(base, "Alex", "Alex"), base);
    assert.equal(renameUploader(base, "", "X"), base);
  });

  it("renameUploaderApplied reflects remaining old names", () => {
    assert.equal(renameUploaderApplied(base, "Alex"), false);
    assert.equal(renameUploaderApplied(renameUploader(base, "Alex", "A"), "Alex"), true);
  });
});

describe("gallery mutation", () => {
  it("touchGallery bumps updatedAt", () => {
    const older: GalleryState = {
      updatedAt: "2024-01-01T00:00:00.000Z",
      order: [],
      photos: {},
    };
    const newer = touchGallery(older);
    assert.ok(newer.updatedAt > older.updatedAt);
  });

  it("empty gallery uses epoch", () => {
    assert.equal(emptyGalleryUpdatedAt(), "1970-01-01T00:00:00.000Z");
  });
});
