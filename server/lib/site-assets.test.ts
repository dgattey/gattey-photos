import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import nextConfig, { LATEST_APPCAST_URL } from "../next.config.ts";

const repoPath = (path: string) => fileURLToPath(new URL(`../../${path}`, import.meta.url));

function readIcoFrames(buffer: Buffer): { size: number; isPng: boolean }[] {
  assert.equal(buffer.readUInt16LE(0), 0, "favicon.ico reserved header");
  assert.equal(buffer.readUInt16LE(2), 1, "favicon.ico type is icon");
  const count = buffer.readUInt16LE(4);
  return Array.from({ length: count }, (_, index) => {
    const entry = 6 + index * 16;
    const size = buffer[entry] || 256;
    const offset = buffer.readUInt32LE(entry + 12);
    const isPng = buffer.subarray(offset, offset + 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
    return { size, isPng };
  });
}

async function assertPngSize(path: string, size: number) {
  const metadata = await sharp(repoPath(path)).metadata();
  assert.equal(metadata.format, "png", `${path} is not a PNG`);
  assert.deepEqual([metadata.width, metadata.height], [size, size], `${path} must be ${size}×${size}`);
}

/** URL contract dyl-kit and dylangattey.com read from every <app>.gattey.com site. */
describe("photos.gattey.com icons", () => {
  it("serves /icon.png at 1024×1024", async () => {
    await assertPngSize("server/public/icon.png", 1024);
    const { depth } = await sharp(repoPath("server/public/icon.png")).metadata();
    const { size } = statSync(repoPath("server/public/icon.png"));
    assert.equal(depth, "uchar", "icon.png should be 8-bit; ictool exports 16-bit");
    assert.ok(size < 500_000, `icon.png is ${size} bytes`);
    assert.ok(
      !existsSync(repoPath("server/app/icon.png")),
      "server/app/icon.png would shadow /icon.png; keep the 1024px icon in server/public/",
    );
  });

  it("serves both shared icons cross-origin with an hour of caching", async () => {
    const rules = (await nextConfig.headers?.()) ?? [];
    for (const path of ["/icon.png", "/apple-touch-icon.png"]) {
      const headers = new Map(
        rules.find((rule) => rule.source === path)?.headers.map((h) => [h.key, h.value]),
      );
      assert.equal(
        headers.get("Cache-Control"),
        "public, max-age=3600, stale-while-revalidate=86400",
        `${path} Cache-Control`,
      );
      assert.equal(headers.get("Access-Control-Allow-Origin"), "*", `${path} CORS`);
    }
  });

  it("serves an opaque full-bleed /apple-touch-icon.png so iOS never fills black corners", async () => {
    const { isOpaque } = await sharp(repoPath("server/public/apple-touch-icon.png")).stats();
    assert.ok(isOpaque, "apple-touch-icon.png has transparent pixels");
  });

  it("serves /apple-touch-icon.png and @dylkit/web's /apple-icon.png as the same 180×180 PNG", async () => {
    await assertPngSize("server/public/apple-touch-icon.png", 180);
    await assertPngSize("server/public/apple-icon.png", 180);
    assert.ok(
      readFileSync(repoPath("server/public/apple-touch-icon.png")).equals(
        readFileSync(repoPath("server/public/apple-icon.png")),
      ),
      "apple-touch-icon.png and apple-icon.png differ",
    );
  });

  it("packs 16px and 32px PNG frames into favicon.ico", () => {
    const frames = readIcoFrames(readFileSync(repoPath("server/app/favicon.ico")));
    assert.deepEqual(
      frames.map((frame) => frame.size),
      [16, 32],
    );
    assert.ok(frames.every((frame) => frame.isPng));
  });
});

describe("photos.gattey.com/appcast.xml", () => {
  it("temporarily redirects Sparkle's SUFeedURL to the latest GitHub release's appcast", async () => {
    const redirects = (await nextConfig.redirects?.()) ?? [];
    const rule = redirects.find((redirect) => redirect.source === "/appcast.xml");
    assert.ok(rule, "no /appcast.xml redirect");
    assert.equal(rule.destination, LATEST_APPCAST_URL);
    assert.equal(rule.permanent, false, "a permanent redirect would pin Sparkle and caches to one target");
  });
});
