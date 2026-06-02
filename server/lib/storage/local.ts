import fs from "fs/promises";
import path from "path";
import type { CurrentManifest, RawCurrent, RawManifest } from "../types";
import { CURRENT_PATH, MANIFEST_PATH } from "../gallery";

const root = () => path.join(process.cwd(), ".data");

async function ensureDir(filePath: string) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
}

export async function readManifest(): Promise<RawManifest> {
  const file = path.join(root(), MANIFEST_PATH);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as RawManifest;
  } catch {
    return {};
  }
}

export async function readCurrent(): Promise<RawCurrent | null> {
  const file = path.join(root(), CURRENT_PATH);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as RawCurrent;
  } catch {
    return null;
  }
}

export async function writeManifest(library: RawManifest): Promise<void> {
  const file = path.join(root(), MANIFEST_PATH);
  await ensureDir(file);
  await fs.writeFile(file, JSON.stringify(library, null, 2), "utf8");
}

export async function writeCurrent(current: CurrentManifest): Promise<void> {
  const file = path.join(root(), CURRENT_PATH);
  await ensureDir(file);
  await fs.writeFile(file, JSON.stringify(current, null, 2), "utf8");
}

export async function putBytes(blobPath: string, bytes: Buffer): Promise<void> {
  const file = path.join(root(), blobPath);
  await ensureDir(file);
  await fs.writeFile(file, bytes);
}

export async function getBytes(blobPath: string): Promise<Buffer | null> {
  const file = path.join(root(), blobPath);
  try {
    return await fs.readFile(file);
  } catch {
    return null;
  }
}

export function localDownloadUrl(request: Request, blobPath: string): string {
  const base = new URL(request.url);
  base.pathname = `/api/gallery/blob/${encodeURIComponent(blobPath)}`;
  base.search = "";
  return base.toString();
}
