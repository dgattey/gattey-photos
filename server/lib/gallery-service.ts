import type { GalleryResponse, GalleryState } from "./types";

/// Clients build image URLs from the photo id, so the response carries only the assembled state
/// (no duplicated photos array, no per-photo download URLs).
export function buildGalleryResponse(state: GalleryState): GalleryResponse {
  return { state };
}
