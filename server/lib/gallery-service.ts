import type { GalleryResponse, GalleryState } from "./types";
import * as storage from "./storage";

/// Clients build image URLs from the photo id, so the response carries only the assembled state
/// (no duplicated photos array, no per-photo download URLs).
export function buildGalleryResponse(state: GalleryState): GalleryResponse {
  return { state };
}

export async function loadGallery(): Promise<GalleryResponse> {
  return buildGalleryResponse(await storage.readManifest());
}
