import { list } from "@vercel/blob";
import type { CurrentManifest, RawCurrent, RawManifest } from "../types";
import { CURRENT_PATH, MANIFEST_PATH } from "../gallery";
import { readBlobBytes, writeBlob } from "./blob-access";

/// Library + current are mutable: read from origin (no CDN cache) so a delete/upload/rotate is
/// immediately visible on the next pull instead of resurrecting from a stale cached copy.
export async function readManifest(): Promise<RawManifest> {
  const bytes = await readBlobBytes(MANIFEST_PATH, false);
  if (!bytes) return {};
  try {
    return JSON.parse(bytes.toString("utf8")) as RawManifest;
  } catch {
    return {};
  }
}

export async function readCurrent(): Promise<RawCurrent | null> {
  const bytes = await readBlobBytes(CURRENT_PATH, false);
  if (!bytes) return null;
  try {
    return JSON.parse(bytes.toString("utf8")) as RawCurrent;
  } catch {
    return null;
  }
}

/// 60s is the minimum cache the SDK allows; combined with origin reads it bounds staleness for any
/// consumer that does read through the CDN.
export async function writeManifest(library: RawManifest): Promise<void> {
  await writeBlob(MANIFEST_PATH, JSON.stringify(library), "application/json", 60);
}

export async function writeCurrent(current: CurrentManifest): Promise<void> {
  await writeBlob(CURRENT_PATH, JSON.stringify(current), "application/json", 60);
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
