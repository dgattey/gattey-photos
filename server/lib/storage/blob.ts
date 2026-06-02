import { list } from "@vercel/blob";
import type { GalleryState, RawManifest } from "../types";
import { MANIFEST_PATH, emptyGallery } from "../gallery";
import { readBlobBytes, writeBlob } from "./blob-access";

export async function readManifest(): Promise<RawManifest> {
  const bytes = await readBlobBytes(MANIFEST_PATH);
  if (!bytes) return emptyGallery();
  try {
    return JSON.parse(bytes.toString("utf8")) as RawManifest;
  } catch {
    return emptyGallery();
  }
}

export async function writeManifest(state: GalleryState): Promise<void> {
  await writeBlob(MANIFEST_PATH, JSON.stringify(state), "application/json");
}

export async function putBytes(blobPath: string, bytes: Buffer): Promise<string> {
  await writeBlob(blobPath, bytes, "image/jpeg");
  return blobPath;
}

export async function readPhotoBytes(blobPath: string): Promise<Buffer | null> {
  return readBlobBytes(blobPath);
}

export async function listPhotoBlobs(): Promise<string[]> {
  const { blobs } = await list({ prefix: "photos/" });
  return blobs.map((b) => b.pathname);
}
