import type { GalleryState } from "./types";
import { pushCurrentPhotoToAllDevices } from "./bloomin8/push-gallery";
import * as storage from "./storage";

/** Persist manifest, then push current photo to all registered frames. Manifest always saves. */
export async function commitManifest(state: GalleryState): Promise<GalleryState> {
  const saved = await storage.writeManifest(state);
  await pushCurrentPhotoToAllDevices(saved);
  return saved;
}
