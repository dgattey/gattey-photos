import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, it } from "node:test";
import { mintSessionToken } from "../auth";
import { uploaderIdForName } from "../gallery";
import {
  filterDevicesByOwner,
  listDevices,
  listDevicesDecrypted,
  registerDevice,
  renameDeviceOwner,
} from "./registry";
import * as registryStorage from "../storage/registry-storage";

const TOKEN_A = `Device: Bedroom\nToken: ${"a".repeat(16)}.${"b".repeat(48)}`;
const TOKEN_B = `Device: Casa lapa\nToken: ${"c".repeat(16)}.${"d".repeat(48)}`;

describe("filterDevicesByOwner", () => {
  const sample = [
    { id: "1", displayName: "Bedroom", registeredBy: "Dylan" },
    { id: "2", displayName: "Casa lapa", registeredBy: "Becca" },
  ];

  it("returns all devices when owner is omitted or blank", () => {
    assert.deepEqual(filterDevicesByOwner(sample), sample);
    assert.deepEqual(filterDevicesByOwner(sample, null), sample);
    assert.deepEqual(filterDevicesByOwner(sample, "   "), sample);
  });

  it("filters case-insensitively and trims whitespace", () => {
    assert.deepEqual(filterDevicesByOwner(sample, "  dylan "), [sample[0]]);
    assert.deepEqual(filterDevicesByOwner(sample, "BECCA"), [sample[1]]);
    assert.deepEqual(filterDevicesByOwner(sample, "Other"), []);
  });
});

describe("device registry owner filtering and uploader rename", () => {
  let prevCwd: string;
  let prevLocal: string | undefined;
  let prevPassword: string | undefined;
  let dir: string;
  const secret = "test-family-password";

  beforeEach(async () => {
    prevCwd = process.cwd();
    prevLocal = process.env.GATTEY_LOCAL_STORAGE;
    prevPassword = process.env.SYNC_PASSWORD;
    dir = await fs.mkdtemp(path.join(os.tmpdir(), "devices-registry-"));
    process.chdir(dir);
    process.env.GATTEY_LOCAL_STORAGE = "1";
    process.env.SYNC_PASSWORD = secret;
  });

  afterEach(async () => {
    process.chdir(prevCwd);
    if (prevLocal === undefined) delete process.env.GATTEY_LOCAL_STORAGE;
    else process.env.GATTEY_LOCAL_STORAGE = prevLocal;
    if (prevPassword === undefined) delete process.env.SYNC_PASSWORD;
    else process.env.SYNC_PASSWORD = prevPassword;
    await fs.rm(dir, { recursive: true, force: true });
  });

  it("listDevices and listDevicesDecrypted filter by owner when provided", async () => {
    await registerDevice({ setupText: TOKEN_A, registeredBy: "Dylan" });
    await registerDevice({ setupText: TOKEN_B, registeredBy: "Becca" });

    const all = await listDevices();
    assert.equal(all.length, 2);

    const dylanOnly = await listDevices("dylan");
    assert.equal(dylanOnly.length, 1);
    assert.equal(dylanOnly[0]?.displayName, "Bedroom");
    assert.equal(dylanOnly[0]?.registeredBy, "Dylan");

    const beccaDecrypted = await listDevicesDecrypted("  Becca  ");
    assert.equal(beccaDecrypted.length, 1);
    assert.equal(beccaDecrypted[0]?.displayName, "Casa lapa");

    const unfilteredDecrypted = await listDevicesDecrypted();
    assert.equal(unfilteredDecrypted.length, 2);
  });

  it("GET /api/devices filters by ?owner= query parameter", async () => {
    await registerDevice({ setupText: TOKEN_A, registeredBy: "Dylan" });
    await registerDevice({ setupText: TOKEN_B, registeredBy: "Becca" });

    const { GET } = await import("@/app/api/devices/route");
    const session = mintSessionToken(secret);

    const resDylan = await GET(
      new Request("https://photos.gattey.com/api/devices?owner=Dylan", {
        headers: { Authorization: `Bearer ${session}` },
      })
    );
    const bodyDylan = (await resDylan.json()) as {
      devices: Array<{ displayName: string; registeredBy: string }>;
    };
    assert.equal(bodyDylan.devices.length, 1);
    assert.equal(bodyDylan.devices[0]?.displayName, "Bedroom");

    const resAll = await GET(
      new Request("https://photos.gattey.com/api/devices", {
        headers: { Authorization: `Bearer ${session}` },
      })
    );
    const bodyAll = (await resAll.json()) as {
      devices: Array<{ displayName: string; registeredBy: string }>;
    };
    assert.equal(bodyAll.devices.length, 2);
  });

  it("GET /api/devices/status includes registeredBy and polls only matching owner devices", async () => {
    await registerDevice({ setupText: TOKEN_A, registeredBy: "Dylan" });
    await registerDevice({ setupText: TOKEN_B, registeredBy: "Becca" });

    const originalFetch = globalThis.fetch;
    const polledAuthHeaders: string[] = [];
    globalThis.fetch = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      const headers = new Headers(init?.headers);
      polledAuthHeaders.push(headers.get("Authorization") ?? "");
      return new Response(
        JSON.stringify({
          success: true,
          device: {
            name: "Bloomin8",
            width: 1200,
            height: 1600,
            orientation: "portrait",
            remote_image_on: true,
            remote_image_interval: "24h",
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }) as typeof fetch;

    try {
      const { GET } = await import("@/app/api/devices/status/route");
      const session = mintSessionToken(secret);
      const res = await GET(
        new Request("https://photos.gattey.com/api/devices/status?owner=Dylan", {
          headers: { Authorization: `Bearer ${session}` },
        })
      );
      const body = (await res.json()) as {
        devices: Array<{
          displayName: string;
          registeredBy?: string;
          reachable: boolean;
        }>;
      };
      assert.equal(polledAuthHeaders.length, 1);
      assert.equal(body.devices.length, 1);
      assert.equal(body.devices[0]?.displayName, "Bedroom");
      assert.equal(body.devices[0]?.registeredBy, "Dylan");
      assert.equal(body.devices[0]?.reachable, true);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it("renameDeviceOwner and PATCH /api/gallery/uploaders update matching registeredBy entries", async () => {
    await registerDevice({ setupText: TOKEN_A, registeredBy: "Dylan" });
    await registerDevice({ setupText: TOKEN_B, registeredBy: "Becca" });

    const changed = await renameDeviceOwner("dylan", "Dylan Gattey");
    assert.equal(changed, true);

    const afterDirect = await listDevices("Dylan Gattey");
    assert.equal(afterDirect.length, 1);
    assert.equal(afterDirect[0]?.displayName, "Bedroom");

    const manifestFile = path.join(dir, ".data", "gallery/manifest.json");
    await fs.mkdir(path.dirname(manifestFile), { recursive: true });
    const dylanId = uploaderIdForName("Dylan Gattey");
    const beccaId = uploaderIdForName("Becca");
    const base = "2026-10-15T12:00:00.000Z";
    await fs.writeFile(
      manifestFile,
      JSON.stringify({
        updatedAt: base,
        order: [],
        photos: {},
        uploaders: {
          [dylanId]: "Dylan Gattey",
          [beccaId]: "Becca",
        },
        currentPhotoId: null,
      }),
      "utf8"
    );

    const { PATCH } = await import("@/app/api/gallery/uploaders/route");
    const session = mintSessionToken(secret);

    const okRes = await PATCH(
      new Request("https://photos.gattey.com/api/gallery/uploaders", {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${session}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          fromName: "Dylan Gattey",
          toName: "Dylan",
          baseUpdatedAt: base,
        }),
      })
    );
    assert.equal(okRes.status, 200);
    const okBody = (await okRes.json()) as { state: { updatedAt: string } };

    const regAfterOk = await registryStorage.readRegistry();
    assert.equal(
      regAfterOk.devices.find((d) => d.displayName === "Bedroom")?.registeredBy,
      "Dylan"
    );

    const collisionRes = await PATCH(
      new Request("https://photos.gattey.com/api/gallery/uploaders", {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${session}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          fromName: "Dylan",
          toName: "Becca",
          baseUpdatedAt: okBody.state.updatedAt,
        }),
      })
    );
    assert.equal(collisionRes.status, 200);

    const regAfterCollision = await registryStorage.readRegistry();
    assert.equal(
      regAfterCollision.devices.find((d) => d.displayName === "Bedroom")?.registeredBy,
      "Dylan"
    );
  });
});
