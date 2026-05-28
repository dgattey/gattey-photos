import { head, list, put } from "@vercel/blob";
import type { GalleryState } from "../types";
import { MANIFEST_PATH, emptyGallery } from "../gallery";

export async function readManifest(): Promise<GalleryState> {
  try {
    const meta = await head(MANIFEST_PATH);
    const res = await fetch(meta.url);
    if (!res.ok) return emptyGallery();
    return (await res.json()) as GalleryState;
  } catch {
    return emptyGallery();
  }
}

export async function writeManifest(state: GalleryState): Promise<void> {
  await put(MANIFEST_PATH, JSON.stringify(state), {
    access: "public",
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: "application/json",
  });
}

export async function putBytes(blobPath: string, bytes: Buffer): Promise<string> {
  const result = await put(blobPath, bytes, {
    access: "public",
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: "image/jpeg",
  });
  return result.url;
}

export async function getBytesUrl(blobPath: string): Promise<string | null> {
  try {
    const meta = await head(blobPath);
    return meta.url;
  } catch {
    return null;
  }
}

export async function listPhotoBlobs(): Promise<string[]> {
  const { blobs } = await list({ prefix: "photos/" });
  return blobs.map((b) => b.pathname);
}
