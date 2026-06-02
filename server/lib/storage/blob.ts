import { list } from "@vercel/blob";
import type { GalleryState, RawManifest } from "../types";
import { MANIFEST_PATH, emptyGallery } from "../gallery";
import { readBlobBytes, writeBlob } from "./blob-access";

/// Manifest is mutable: read from origin (no CDN cache) so a delete/upload is immediately visible
/// on the next pull instead of resurrecting from a stale cached copy.
export async function readManifest(): Promise<RawManifest> {
  const bytes = await readBlobBytes(MANIFEST_PATH, false);
  if (!bytes) return emptyGallery();
  try {
    return JSON.parse(bytes.toString("utf8")) as RawManifest;
  } catch {
    return emptyGallery();
  }
}

/// 60s is the minimum cache the SDK allows; combined with origin reads it bounds staleness for any
/// consumer that does read through the CDN.
export async function writeManifest(state: GalleryState): Promise<void> {
  await writeBlob(MANIFEST_PATH, JSON.stringify(state), "application/json", 60);
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
