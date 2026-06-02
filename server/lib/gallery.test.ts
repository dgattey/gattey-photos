import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  coalesceUploaders,
  legacyUploaderId,
  renameUploader,
} from "./gallery";
import { emptyGalleryUpdatedAt, touchGallery } from "./gallery-mutation";
import type { GalleryState, RawPhotoEntry } from "./types";

function photo(id: string, uploaderId: string) {
  return {
    id,
    filename: `${id}.jpg`,
    blobPath: `photos/${id}.jpg`,
    sizeBytes: 1,
    updatedAt: "2020-01-01T00:00:00.000Z",
    deletedAt: null,
    uploaderId,
  };
}

describe("renameUploader", () => {
  const alexId = legacyUploaderId("Alex");
  const samId = legacyUploaderId("Sam");
  const base: GalleryState = {
    updatedAt: "2024-01-01T00:00:00.000Z",
    order: ["a", "b"],
    photos: {
      a: photo("a", alexId),
      b: photo("b", samId),
    },
    uploaders: {
      [alexId]: "Alex",
      [samId]: "Sam",
    },
    currentPhotoId: "a",
  };

  it("updates matching uploader names in the map", () => {
    const next = renameUploader(base, "Alex", "Alexander");
    assert.equal(next.uploaders[alexId], "Alexander");
    assert.equal(next.photos.a!.uploaderId, alexId);
    assert.equal(next.uploaders[samId], "Sam");
    assert.equal(next.updatedAt, base.updatedAt);
  });

  it("is a no-op when names match or empty", () => {
    assert.equal(renameUploader(base, "Alex", "Alex"), base);
    assert.equal(renameUploader(base, "", "X"), base);
  });
});

describe("coalesceUploaders", () => {
  it("derives uploader ids from legacy uploadedBy strings", () => {
    const raw: Record<string, RawPhotoEntry> = {
      a: {
        id: "a",
        filename: "a.jpg",
        blobPath: "photos/a.jpg",
        sizeBytes: 1,
        updatedAt: "2020-01-01T00:00:00.000Z",
        deletedAt: null,
        uploadedBy: "Alex",
      },
    };
    const { photos, uploaders } = coalesceUploaders(raw, undefined);
    const alexId = legacyUploaderId("Alex");
    assert.equal(photos.a!.uploaderId, alexId);
    assert.equal(uploaders[alexId], "Alex");
  });

  it("fills missing map entries for existing uploader ids", () => {
    const uid = legacyUploaderId("Sam");
    const raw: Record<string, RawPhotoEntry> = {
      b: {
        id: "b",
        filename: "b.jpg",
        blobPath: "photos/b.jpg",
        sizeBytes: 1,
        updatedAt: "2020-01-01T00:00:00.000Z",
        deletedAt: null,
        uploaderId: uid,
        uploadedBy: "Sam",
      },
    };
    const { uploaders } = coalesceUploaders(raw, {});
    assert.equal(uploaders[uid], "Sam");
  });
});

describe("gallery mutation", () => {
  it("touchGallery bumps updatedAt", () => {
    const older: GalleryState = {
      updatedAt: "2024-01-01T00:00:00.000Z",
      order: [],
      photos: {},
      uploaders: {},
    };
    const newer = touchGallery(older);
    assert.ok(newer.updatedAt > older.updatedAt);
  });

  it("empty gallery uses epoch", () => {
    assert.equal(emptyGalleryUpdatedAt(), "1970-01-01T00:00:00.000Z");
  });
});
