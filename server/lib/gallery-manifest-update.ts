import { ManifestUpdateConflictError } from "./manifest-errors";
import type { GalleryState } from "./types";
import * as storage from "./storage";

export { ManifestUpdateConflictError } from "./manifest-errors";

/**
 * Read-modify-write with verify-and-retry. Concurrent gallery API handlers used to
 * read the same manifest revision and overwrite each other, dropping new uploads.
 */
export async function updateGalleryManifest(
  update: (state: GalleryState) => GalleryState,
  isApplied: (state: GalleryState) => boolean,
  maxAttempts = 10
): Promise<GalleryState> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const state = await storage.readManifest();
    const next = update(state);
    await storage.writeManifest(next);
    const verify = await storage.readManifest();
    if (isApplied(verify)) {
      return verify;
    }
    console.warn(
      `[gallery manifest] update not visible after write (attempt ${attempt + 1}/${maxAttempts})`
    );
  }
  throw new ManifestUpdateConflictError();
}
