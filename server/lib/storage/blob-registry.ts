import type { DeviceRegistry } from "../types";
import { emptyRegistry, REGISTRY_PATH } from "./registry-storage";
import { readBlobBytes, writeBlob } from "./blob-access";

export async function readRegistry(): Promise<DeviceRegistry> {
  const bytes = await readBlobBytes(REGISTRY_PATH);
  if (!bytes) return emptyRegistry();
  try {
    return JSON.parse(bytes.toString("utf8")) as DeviceRegistry;
  } catch {
    return emptyRegistry();
  }
}

export async function writeRegistry(registry: DeviceRegistry): Promise<void> {
  await writeBlob(REGISTRY_PATH, JSON.stringify(registry), "application/json");
}
