import { randomUUID } from "node:crypto";
import type { RegisteredDevice, RegisteredDevicePublic } from "../types";
import { decryptDeviceToken, encryptDeviceToken } from "./crypto";
import { parseBloomin8Token, parseDeviceName } from "./token-parser";
import * as storage from "../storage/registry-storage";

const OPEN_API_DEFAULT =
  process.env.BLOOMIN8_OPEN_API_BASE_URL?.trim() ||
  "https://einkshot-349134901638.us-central1.run.app";

export function toPublicDevice(d: RegisteredDevice): RegisteredDevicePublic {
  return {
    id: d.id,
    displayName: d.displayName,
    registeredBy: d.registeredBy,
    registeredAt: d.registeredAt,
    lastPushAt: d.lastPushAt,
    lastPushError: d.lastPushError,
  };
}

export function filterDevicesByOwner<T extends { registeredBy?: string }>(
  devices: T[],
  owner?: string | null
): T[] {
  const normalizedOwner = owner?.trim().toLowerCase() ?? "";
  if (!normalizedOwner) return devices;
  return devices.filter(
    (d) => (d.registeredBy ?? "").trim().toLowerCase() === normalizedOwner
  );
}

export async function listDevices(
  owner?: string | null
): Promise<RegisteredDevicePublic[]> {
  const registry = await storage.readRegistry();
  const filtered = filterDevicesByOwner(registry.devices, owner);
  return filtered.map(toPublicDevice);
}

export async function listDevicesDecrypted(
  owner?: string | null
): Promise<Array<RegisteredDevice & { token: string }>> {
  const registry = await storage.readRegistry();
  const filtered = filterDevicesByOwner(registry.devices, owner);
  return filtered.map((d) => ({
    ...d,
    token: decryptDeviceToken(d.tokenCiphertext),
  }));
}

export async function renameDeviceOwner(
  fromName: string,
  toName: string
): Promise<boolean> {
  const from = fromName.trim();
  const to = toName.trim();
  if (!from || !to || from === to) return false;
  const fromLower = from.toLowerCase();

  const registry = await storage.readRegistry();
  let changed = false;
  for (const device of registry.devices) {
    if ((device.registeredBy ?? "").trim().toLowerCase() === fromLower) {
      if (device.registeredBy !== to) {
        device.registeredBy = to;
        changed = true;
      }
    }
  }
  if (!changed) return false;
  registry.version += 1;
  await storage.writeRegistry(registry);
  return true;
}

export async function registerDevice(input: {
  setupText: string;
  displayName?: string;
  registeredBy: string;
}): Promise<RegisteredDevicePublic> {
  const token = parseBloomin8Token(input.setupText);
  if (!token) {
    throw new Error("Could not parse Bloomin8 token from pasted text");
  }
  const parsedName = parseDeviceName(input.setupText);
  const displayName =
    input.displayName?.trim() ||
    parsedName ||
    "Bloomin8 frame";

  const registry = await storage.readRegistry();
  const existing = registry.devices.find(
    (d) => decryptDeviceToken(d.tokenCiphertext) === token
  );
  if (existing) {
    existing.displayName = displayName;
    existing.registeredBy = input.registeredBy;
    await storage.writeRegistry(registry);
    return toPublicDevice(existing);
  }

  const device: RegisteredDevice = {
    id: randomUUID(),
    displayName,
    tokenCiphertext: encryptDeviceToken(token),
    openApiBaseURL: OPEN_API_DEFAULT,
    registeredBy: input.registeredBy,
    registeredAt: new Date().toISOString(),
  };
  registry.devices.push(device);
  registry.version += 1;
  await storage.writeRegistry(registry);
  return toPublicDevice(device);
}

export async function removeDevice(id: string): Promise<boolean> {
  const registry = await storage.readRegistry();
  const before = registry.devices.length;
  registry.devices = registry.devices.filter((d) => d.id !== id);
  if (registry.devices.length === before) return false;
  registry.version += 1;
  await storage.writeRegistry(registry);
  return true;
}

export type DevicePushOutcome = {
  id: string;
  ok: boolean;
  error?: string;
};

/**
 * Persist a batch of push outcomes in a single registry write. We deliberately
 * do NOT stamp `lastPushAt` on a plain success: doing so would force an advanced
 * Blob `put` on every rotation just to record a timestamp. The write is skipped
 * entirely unless a device's error state actually changed (a new failure, or a
 * success clearing a prior error), so a healthy push of N frames costs 0 puts.
 */
export async function recordDevicePushResults(
  outcomes: DevicePushOutcome[]
): Promise<void> {
  if (outcomes.length === 0) return;
  const registry = await storage.readRegistry();
  const now = new Date().toISOString();
  let changed = false;
  for (const outcome of outcomes) {
    const device = registry.devices.find((d) => d.id === outcome.id);
    if (!device) continue;
    const nextError = outcome.ok ? undefined : outcome.error ?? "push failed";
    if (device.lastPushError === nextError) continue;
    device.lastPushError = nextError;
    device.lastPushAt = now;
    changed = true;
  }
  if (!changed) return;
  await storage.writeRegistry(registry);
}
