import { randomUUID } from "node:crypto";
import type { DeviceRegistry, RegisteredDevice, RegisteredDevicePublic } from "../types";
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

export async function listDevices(): Promise<RegisteredDevicePublic[]> {
  const registry = await storage.readRegistry();
  return registry.devices.map(toPublicDevice);
}

export async function listDevicesDecrypted(): Promise<
  Array<RegisteredDevice & { token: string }>
> {
  const registry = await storage.readRegistry();
  return registry.devices.map((d) => ({
    ...d,
    token: decryptDeviceToken(d.tokenCiphertext),
  }));
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

export async function recordDevicePushResult(
  id: string,
  ok: boolean,
  detail?: string
): Promise<void> {
  const registry = await storage.readRegistry();
  const device = registry.devices.find((d) => d.id === id);
  if (!device) return;
  device.lastPushAt = new Date().toISOString();
  device.lastPushError = ok ? undefined : detail ?? "push failed";
  await storage.writeRegistry(registry);
}
