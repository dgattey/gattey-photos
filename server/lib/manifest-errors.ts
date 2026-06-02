import type { GalleryState } from "./types";

export class ManifestUpdateConflictError extends Error {
  constructor(message = "gallery manifest update conflict after retries") {
    super(message);
    this.name = "ManifestUpdateConflictError";
  }
}

/** Client `baseUpdatedAt` is older than the manifest on disk. */
export class StaleGalleryError extends Error {
  readonly state: GalleryState;

  constructor(state: GalleryState) {
    super("gallery manifest is newer than client base");
    this.name = "StaleGalleryError";
    this.state = state;
  }
}
