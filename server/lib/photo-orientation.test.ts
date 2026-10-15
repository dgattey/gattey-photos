import assert from "node:assert/strict";
import fs from "node:fs/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, it } from "node:test";
import sharp from "sharp";
import { pushCurrentPhotoToAllDevices } from "./bloomin8/push-gallery";
import { encryptDeviceToken } from "./devices/crypto";
import { uploaderIdForName } from "./gallery";
import { normalizePhotoOrientation } from "./photo-orientation";
import * as storage from "./storage";
import { writeRegistry } from "./storage/registry-storage";
import type { GalleryState } from "./types";

async function makeOrientedJpeg(
  width: number,
  height: number,
  orientation: number
): Promise<Buffer> {
  const raw = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 3;
      const isTopLeft = x < width / 2 && y < height / 2;
      raw[idx] = isTopLeft ? 255 : 0;
      raw[idx + 1] = 0;
      raw[idx + 2] = isTopLeft ? 0 : 255;
    }
  }
  return sharp(raw, { raw: { width, height, channels: 3 } })
    .withMetadata({ orientation })
    .jpeg({ quality: 95 })
    .toBuffer();
}

function extractMultipartJpeg(body: Buffer, contentType: string): Buffer {
  const match = /boundary=([^\s;]+)/i.exec(contentType);
  assert.ok(match, "expected multipart boundary");
  const headerEnd = body.indexOf(Buffer.from("\r\n\r\n", "utf8"));
  assert.ok(headerEnd > 0, "expected multipart headers");
  const start = headerEnd + 4;
  const trailer = Buffer.from(`\r\n--${match[1]}--`, "utf8");
  const end = body.indexOf(trailer, start);
  assert.ok(end > start, "expected multipart closing boundary");
  return body.subarray(start, end);
}

describe("normalizePhotoOrientation", () => {
  it("returns upright (orientation 1) JPEGs unchanged without re-encoding", async () => {
    const upright = await makeOrientedJpeg(40, 20, 1);
    const result = await normalizePhotoOrientation(upright);
    assert.equal(result.didRotate, false);
    assert.equal(result.bytes, upright);
  });

  it("rotates EXIF orientation 3 (180° upside down, like IMG_0873.jpeg) into upright pixels", async () => {
    const upsideDown = await makeOrientedJpeg(40, 20, 3);
    const beforeMeta = await sharp(upsideDown).metadata();
    assert.equal(beforeMeta.orientation, 3);

    const result = await normalizePhotoOrientation(upsideDown);
    assert.equal(result.didRotate, true);

    const afterMeta = await sharp(result.bytes).metadata();
    assert.equal(afterMeta.width, 40);
    assert.equal(afterMeta.height, 20);
    assert.ok(
      afterMeta.orientation === undefined || afterMeta.orientation === 1,
      `expected cleared orientation, got ${afterMeta.orientation}`
    );

    const { data, info } = await sharp(result.bytes)
      .raw()
      .toBuffer({ resolveWithObject: true });
    const topLeftRed = data[(5 * info.width + 5) * info.channels]!;
    const bottomRightRed = data[(15 * info.width + 35) * info.channels]!;
    assert.ok(topLeftRed < 80, `expected top-left to be blue after 180° rotation, red=${topLeftRed}`);
    assert.ok(bottomRightRed > 180, `expected bottom-right to be red after 180° rotation, red=${bottomRightRed}`);
  });

  it("rotates EXIF orientation 6 (90° CW sideways, like IMG_0823/IMG_3008) into portrait pixels", async () => {
    const sideways = await makeOrientedJpeg(40, 20, 6);
    const beforeMeta = await sharp(sideways).metadata();
    assert.equal(beforeMeta.width, 40);
    assert.equal(beforeMeta.height, 20);
    assert.equal(beforeMeta.orientation, 6);

    const result = await normalizePhotoOrientation(sideways);
    assert.equal(result.didRotate, true);

    const afterMeta = await sharp(result.bytes).metadata();
    assert.equal(afterMeta.width, 20);
    assert.equal(afterMeta.height, 40);
    assert.ok(
      afterMeta.orientation === undefined || afterMeta.orientation === 1,
      `expected cleared orientation, got ${afterMeta.orientation}`
    );
  });
});

describe("pushCurrentPhotoToAllDevices orientation normalization", () => {
  let prevCwd: string;
  let prevLocal: string | undefined;
  let prevPassword: string | undefined;
  let dir: string;
  let server: http.Server;
  let baseUrl: string;
  let pushedJpegs: Buffer[];

  beforeEach(async () => {
    prevCwd = process.cwd();
    prevLocal = process.env.GATTEY_LOCAL_STORAGE;
    prevPassword = process.env.SYNC_PASSWORD;
    dir = await fs.mkdtemp(path.join(os.tmpdir(), "push-orientation-"));
    process.chdir(dir);
    process.env.GATTEY_LOCAL_STORAGE = "1";
    process.env.SYNC_PASSWORD = "test-sync-password";
    pushedJpegs = [];

    server = http.createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on("data", (c: Buffer) => chunks.push(c));
      req.on("end", () => {
        const body = Buffer.concat(chunks);
        const ct = String(req.headers["content-type"] ?? "");
        pushedJpegs.push(extractMultipartJpeg(body, ct));
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(
          JSON.stringify({
            success: true,
            remote_image_id: "img-1",
            estimated_push_time: "2026-10-15T12:00:00Z",
          })
        );
      });
    });
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const addr = server.address();
    assert.ok(addr && typeof addr === "object");
    baseUrl = `http://127.0.0.1:${addr.port}`;
  });

  afterEach(async () => {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    process.chdir(prevCwd);
    if (prevLocal === undefined) delete process.env.GATTEY_LOCAL_STORAGE;
    else process.env.GATTEY_LOCAL_STORAGE = prevLocal;
    if (prevPassword === undefined) delete process.env.SYNC_PASSWORD;
    else process.env.SYNC_PASSWORD = prevPassword;
    await fs.rm(dir, { recursive: true, force: true });
  });

  it("normalizes a stored EXIF orientation 6 JPEG before pushing to Bloomin8", async () => {
    const sideways = await makeOrientedJpeg(40, 20, 6);
    const photoId = "4601b5b7-107a-4e9e-9c96-f2845a2a910d";
    const blobPath = `photos/${photoId}.jpg`;
    await storage.putPhotoBytes(blobPath, sideways);
    await writeRegistry({
      version: 1,
      devices: [
        {
          id: "dev-1",
          displayName: "Bedroom",
          tokenCiphertext: encryptDeviceToken("tok-bedroom-12345678"),
          openApiBaseURL: baseUrl,
          registeredBy: "Dylan",
          registeredAt: "2026-09-08T21:27:13.914Z",
        },
      ],
    });

    const uploaderId = uploaderIdForName("Becca");
    const state: GalleryState = {
      updatedAt: "2026-09-08T21:27:13.914Z",
      order: [photoId],
      photos: {
        [photoId]: {
          id: photoId,
          filename: "IMG_0873.jpeg",
          blobPath,
          sizeBytes: sideways.length,
          updatedAt: "2026-09-08T21:27:13.914Z",
          deletedAt: null,
          uploaderId,
        },
      },
      uploaders: { [uploaderId]: "Becca" },
      currentPhotoId: photoId,
    };

    const summary = await pushCurrentPhotoToAllDevices(state);
    assert.equal(summary.pushed, 1);
    assert.equal(pushedJpegs.length, 1);

    const pushedMeta = await sharp(pushedJpegs[0]!).metadata();
    assert.equal(pushedMeta.width, 20);
    assert.equal(pushedMeta.height, 40);
    assert.ok(pushedMeta.orientation === undefined || pushedMeta.orientation === 1);

    const healedBytes = await storage.readPhotoBytes(blobPath);
    assert.ok(healedBytes);
    const healedMeta = await sharp(healedBytes).metadata();
    assert.equal(healedMeta.width, 20);
    assert.equal(healedMeta.height, 40);
    assert.ok(healedMeta.orientation === undefined || healedMeta.orientation === 1);
  });
});
