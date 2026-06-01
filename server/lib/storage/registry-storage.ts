import type { DeviceRegistry } from "../types";

export const REGISTRY_PATH = "devices/registry.json";

export function emptyRegistry(): DeviceRegistry {
  return { version: 0, devices: [] };
}

const useLocal = () => process.env.GATTEY_LOCAL_STORAGE === "1";

export async function readRegistry(): Promise<DeviceRegistry> {
  if (useLocal()) {
    const local = await import("./local-registry");
    return local.readRegistry();
  }
  const blob = await import("./blob-registry");
  return blob.readRegistry();
}

export async function writeRegistry(registry: DeviceRegistry): Promise<void> {
  if (useLocal()) {
    const local = await import("./local-registry");
    return local.writeRegistry(registry);
  }
  const blob = await import("./blob-registry");
  return blob.writeRegistry(registry);
}
