import { activeOrder } from "./gallery";
import type { GalleryResponse, GalleryState } from "./types";
import * as storage from "./storage";

export async function buildGalleryResponse(
  request: Request,
  state: GalleryState
): Promise<GalleryResponse> {
  const ids = activeOrder(state);
  const photos = await Promise.all(
    ids.map(async (id) => {
      const entry = state.photos[id]!;
      const base = new URL(request.url);
      base.pathname = `/api/gallery/photos/${entry.id}/image`;
      base.search = "";
      const downloadUrl = base.toString();
      return { ...entry, downloadUrl };
    })
  );
  return { state, photos };
}

export async function loadGallery(request: Request): Promise<GalleryResponse> {
  const state = await storage.readManifest();
  return buildGalleryResponse(request, state);
}
