import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import nextConfig from "../next.config.ts";
import { BRAND } from "./brand.ts";
import { SITE_MEDIA } from "./site-media.ts";

const repoPath = (path: string) => fileURLToPath(new URL(`../../${path}`, import.meta.url));
const SYNC_HINT =
  "The app design changed: update photos.gattey.com (server/app/page.tsx, page.module.css, lib/brand.ts, icons) and ask the dg project to update dylangattey.com. See AGENTS.md.";

function srgbToHex(red: number, green: number, blue: number): string {
  return `#${[red, green, blue]
    .map((channel) => Math.round(channel * 255).toString(16).padStart(2, "0"))
    .join("")}`;
}

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

/** Same bytes `scripts/generate-app-icon.sh` hashes: icon.json, then Assets/* in C-locale order. */
function appIconSourceHash(): string {
  const bundle = repoPath("macos/AppIcon.icon");
  const assets = readdirSync(`${bundle}/Assets`).sort();
  const hash = createHash("sha256");
  hash.update(readFileSync(`${bundle}/icon.json`));
  for (const asset of assets) hash.update(readFileSync(`${bundle}/Assets/${asset}`));
  return hash.digest("hex");
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

  it("serves /apple-touch-icon.png and /apple-icon.png as the same 180×180 PNG", async () => {
    await assertPngSize("server/public/apple-touch-icon.png", 180);
    await assertPngSize("server/app/apple-icon.png", 180);
    assert.ok(
      readFileSync(repoPath("server/public/apple-touch-icon.png")).equals(
        readFileSync(repoPath("server/app/apple-icon.png")),
      ),
      "apple-touch-icon.png and apple-icon.png differ; rerun ./scripts/generate-app-icon.sh",
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

  it("was regenerated from the current macos/AppIcon.icon", () => {
    const recorded = readFileSync(repoPath("server/lib/app-icon-source.sha256"), "utf8").trim();
    assert.equal(
      appIconSourceHash(),
      recorded,
      `macos/AppIcon.icon changed without new web icons. Run ./scripts/generate-app-icon.sh on a Mac. ${SYNC_HINT}`,
    );
  });
});

describe("photos.gattey.com brand colors", () => {
  it("uses AppBrandColor.accentGreen as the brand green", () => {
    const swift = readFileSync(repoPath("macos/Sources/GatteyPhotosUI/AppBrandColor.swift"), "utf8");
    const match = swift.match(
      /accentGreen = Color\(\s*red: ([\d.]+),\s*green: ([\d.]+),\s*blue: ([\d.]+)\s*\)/,
    );
    assert.ok(match, "AppBrandColor.accentGreen not found");
    assert.equal(
      srgbToHex(Number(match[1]), Number(match[2]), Number(match[3])),
      BRAND.green,
      SYNC_HINT,
    );
  });

  it("uses the AppIcon.icon canvas gradient stops", () => {
    const icon = JSON.parse(readFileSync(repoPath("macos/AppIcon.icon/icon.json"), "utf8")) as {
      fill: { "linear-gradient": string[] };
    };
    const [top, bottom] = icon.fill["linear-gradient"].map((stop) => {
      const [red, green, blue] = stop.replace("srgb:", "").split(",").map(Number);
      return srgbToHex(red, green, blue);
    });
    assert.deepEqual([top, bottom], [BRAND.iconGradientTop, BRAND.iconGradientBottom], SYNC_HINT);
  });
});

describe("photos.gattey.com landing media", () => {
  for (const [name, image] of Object.entries(SITE_MEDIA)) {
    it(`ships ${name} at ${image.width}×${image.height}`, async () => {
      const file = repoPath(`server/public${image.src}`);
      assert.ok(existsSync(file), `${image.src} missing from server/public`);
      const metadata = await sharp(file).metadata();
      assert.deepEqual([metadata.width, metadata.height], [image.width, image.height]);
    });
  }

  it("renders public images only through SITE_MEDIA", () => {
    const registered = new Set<string>(Object.values(SITE_MEDIA).map((image) => image.src));
    for (const file of ["server/app/page.tsx", "server/app/layout.tsx"]) {
      const source = readFileSync(repoPath(file), "utf8");
      const literals = [...source.matchAll(/["'`](\/[\w./-]+\.(?:png|jpe?g|webp|gif|svg))["'`]/g)];
      for (const [, src] of literals) {
        assert.ok(registered.has(src), `${file} hardcodes ${src}; add it to lib/site-media.ts`);
      }
    }
  });
});
