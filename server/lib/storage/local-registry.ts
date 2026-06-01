import fs from "fs/promises";
import path from "path";
import type { DeviceRegistry } from "../types";
import { emptyRegistry, REGISTRY_PATH } from "./registry-storage";

const root = () => path.join(process.cwd(), ".data");

async function ensureDir(filePath: string) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
}

export async function readRegistry(): Promise<DeviceRegistry> {
  const file = path.join(root(), REGISTRY_PATH);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as DeviceRegistry;
  } catch {
    return emptyRegistry();
  }
}

export async function writeRegistry(registry: DeviceRegistry): Promise<void> {
  const file = path.join(root(), REGISTRY_PATH);
  await ensureDir(file);
  await fs.writeFile(file, JSON.stringify(registry, null, 2), "utf8");
}
