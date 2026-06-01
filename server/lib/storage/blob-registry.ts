import { head, put } from "@vercel/blob";
import type { DeviceRegistry } from "../types";
import { emptyRegistry, REGISTRY_PATH } from "./registry-storage";

export async function readRegistry(): Promise<DeviceRegistry> {
  try {
    const meta = await head(REGISTRY_PATH);
    const res = await fetch(meta.url);
    if (!res.ok) return emptyRegistry();
    return (await res.json()) as DeviceRegistry;
  } catch {
    return emptyRegistry();
  }
}

export async function writeRegistry(registry: DeviceRegistry): Promise<void> {
  await put(REGISTRY_PATH, JSON.stringify(registry), {
    access: "public",
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: "application/json",
  });
}
