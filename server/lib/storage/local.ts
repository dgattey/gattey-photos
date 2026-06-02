import fs from "fs/promises";
import path from "path";
import type { GalleryState, RawManifest } from "../types";
import { MANIFEST_PATH, emptyGallery } from "../gallery";

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
    return emptyGallery();
  }
}

export async function writeManifest(state: GalleryState): Promise<void> {
  const file = path.join(root(), MANIFEST_PATH);
  await ensureDir(file);
  await fs.writeFile(file, JSON.stringify(state, null, 2), "utf8");
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
