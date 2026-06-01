import * as storage from "./storage";
import type { GalleryState } from "./types";

/** Manifest when gallery storage is reachable; otherwise `null`. */
export async function tryReadManifest(): Promise<GalleryState | null> {
  try {
    return await storage.readManifest();
  } catch {
    return null;
  }
}

export async function isGalleryReachable(): Promise<boolean> {
  return (await tryReadManifest()) !== null;
}
