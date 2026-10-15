import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  coalesceUploaders,
  DEFAULT_UPLOADER_NAME,
  ensureUploaderId,
  renameUploader,
  uploaderIdForName,
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
  const alexId = uploaderIdForName("Alex");
  const samId = uploaderIdForName("Sam");
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

  it("does not overwrite an uploader when renaming to another existing uploader's name", () => {
    const next = renameUploader(base, "Alex", "Sam");
    assert.equal(next.uploaders[alexId], "Alex");
    assert.equal(next.uploaders[samId], "Sam");
  });
});

describe("ensureUploaderId", () => {
  it("does not overwrite an existing uploader id mapped to a different display name", () => {
    const alexId = uploaderIdForName("Alex");
    const state: GalleryState = {
      updatedAt: "2026-08-30T18:30:00.000Z",
      order: ["p1"],
      photos: {
        p1: photo("p1", alexId),
      },
      uploaders: {
        [alexId]: "Sam",
      },
      currentPhotoId: "p1",
    };
    const { state: next, uploaderId } = ensureUploaderId(state, "Alex", alexId);
    assert.notEqual(uploaderId, alexId);
    assert.equal(next.uploaders[alexId], "Sam");
    assert.equal(next.uploaders[uploaderId], "Alex");
  });
});

describe("coalesceUploaders", () => {
  it("defaults a photo without an uploaderId to the default uploader", () => {
    const raw: Record<string, RawPhotoEntry> = {
      a: {
        id: "a",
        filename: "a.jpg",
        blobPath: "photos/a.jpg",
        sizeBytes: 1,
        updatedAt: "2020-01-01T00:00:00.000Z",
        deletedAt: null,
      },
    };
    const { photos, uploaders } = coalesceUploaders(raw, undefined);
    const defId = uploaderIdForName(DEFAULT_UPLOADER_NAME);
    assert.equal(photos.a!.uploaderId, defId);
    assert.equal(uploaders[defId], DEFAULT_UPLOADER_NAME);
  });

  it("fills a missing map entry for an existing uploader id", () => {
    const uid = uploaderIdForName("Sam");
    const raw: Record<string, RawPhotoEntry> = {
      b: {
        id: "b",
        filename: "b.jpg",
        blobPath: "photos/b.jpg",
        sizeBytes: 1,
        updatedAt: "2020-01-01T00:00:00.000Z",
        deletedAt: null,
        uploaderId: uid,
      },
    };
    const { uploaders } = coalesceUploaders(raw, {});
    assert.equal(uploaders[uid], DEFAULT_UPLOADER_NAME);
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
