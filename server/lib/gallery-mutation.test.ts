import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, it } from "node:test";
import { emptyGalleryUpdatedAt } from "./gallery-mutation";
import { softDelete, uploaderIdForName } from "./gallery";
import type { PhotoEntry, PhotoId } from "./types";

function photo(id: PhotoId): PhotoEntry {
  const uploaderId = uploaderIdForName("Test");
  return {
    id,
    filename: `${id}.jpg`,
    blobPath: `photos/${id}.jpg`,
    sizeBytes: 1,
    updatedAt: "2024-01-01T00:00:00.000Z",
    deletedAt: null,
    uploaderId,
  };
}

function manifestBody(photos: Record<PhotoId, PhotoEntry>, extra: Record<string, unknown> = {}) {
  const uploaderId = uploaderIdForName("Test");
  return {
    updatedAt: "2024-06-01T12:00:00.000Z",
    order: Object.keys(photos),
    photos,
    uploaders: { [uploaderId]: "Test" },
    currentPhotoId: "a",
    ...extra,
  };
}

describe("local-storage manifest round trips", () => {
  let prevCwd: string;
  let prevLocal: string | undefined;
  let dir: string;
  let manifestFile: string;

  beforeEach(async () => {
    prevCwd = process.cwd();
    prevLocal = process.env.GATTEY_LOCAL_STORAGE;
    dir = await fs.mkdtemp(path.join(os.tmpdir(), "gallery-mutation-"));
    process.chdir(dir);
    process.env.GATTEY_LOCAL_STORAGE = "1";
    manifestFile = path.join(dir, ".data", "gallery/manifest.json");
    await fs.mkdir(path.dirname(manifestFile), { recursive: true });
  });

  afterEach(async () => {
    process.chdir(prevCwd);
    if (prevLocal === undefined) delete process.env.GATTEY_LOCAL_STORAGE;
    else process.env.GATTEY_LOCAL_STORAGE = prevLocal;
    await fs.rm(dir, { recursive: true, force: true });
  });

  it("readManifest repairs state in memory and never writes back", async () => {
    const onDisk = JSON.stringify(manifestBody({ a: photo("a"), b: photo("b") }, { currentPhotoId: "ghost" }), null, 2);
    await fs.writeFile(manifestFile, onDisk, "utf8");

    const storage = await import("./storage");
    const read = await storage.readManifest();

    assert.equal(read.currentPhotoId, "a");
    assert.equal(await fs.readFile(manifestFile, "utf8"), onDisk);
  });

  it("applyGalleryMutation persists once and returns the written state", async () => {
    const base = "2024-06-01T12:00:00.000Z";
    await fs.writeFile(
      manifestFile,
      JSON.stringify(manifestBody({ a: photo("a"), b: photo("b") }, { updatedAt: base })),
      "utf8"
    );

    const { applyGalleryMutation } = await import("./gallery-mutation");
    const saved = await applyGalleryMutation(base, (s) => softDelete(s, "a") ?? s);

    assert.ok(saved.photos.a?.deletedAt != null);
    assert.notEqual(saved.updatedAt, base);
    const persisted = JSON.parse(await fs.readFile(manifestFile, "utf8"));
    assert.equal(persisted.updatedAt, saved.updatedAt);
    assert.ok(persisted.photos.a?.deletedAt != null);
  });

  it("applyGalleryMutation rejects a stale base with StaleGalleryError", async () => {
    await fs.writeFile(
      manifestFile,
      JSON.stringify(manifestBody({ a: photo("a"), b: photo("b") })),
      "utf8"
    );

    const { applyGalleryMutation } = await import("./gallery-mutation");
    const { StaleGalleryError } = await import("./manifest-errors");
    await assert.rejects(
      () => applyGalleryMutation("2024-01-01T00:00:00.000Z", (s) => s),
      StaleGalleryError
    );
  });
  it("readManifestIfModified returns modified=false on matching ETag and state on mismatch", async () => {
    const base = "2024-06-01T12:00:00.000Z";
    await fs.writeFile(
      manifestFile,
      JSON.stringify(manifestBody({ a: photo("a"), b: photo("b") }, { updatedAt: base })),
      "utf8"
    );

    const storage = await import("./storage");
    const hit = await storage.readManifestIfModified(`"${base}"`);
    assert.equal(hit.modified, false);
    assert.equal(hit.etag, `"${base}"`);

    const miss = await storage.readManifestIfModified(`"2020-01-01T00:00:00.000Z"`);
    assert.equal(miss.modified, true);
    if (miss.modified) {
      assert.equal(miss.state.updatedAt, base);
    }
  });
});

describe("emptyGalleryUpdatedAt", () => {
  it("uses epoch so first client write can proceed", () => {
    assert.equal(emptyGalleryUpdatedAt(), "1970-01-01T00:00:00.000Z");
  });
});
