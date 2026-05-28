import type { GalleryState, PhotoEntry, PhotoId } from "./types";

export const MANIFEST_PATH = "gallery/manifest.json";

export function emptyGallery(): GalleryState {
  return { version: 0, order: [], photos: {} };
}

export function activeOrder(state: GalleryState): PhotoId[] {
  return state.order.filter((id) => {
    const p = state.photos[id];
    return p && p.deletedAt === null;
  });
}

export function bump(state: GalleryState): GalleryState {
  return { ...state, version: state.version + 1 };
}

export function softDelete(state: GalleryState, id: PhotoId): GalleryState {
  const photo = state.photos[id];
  if (!photo || photo.deletedAt) return state;
  const now = new Date().toISOString();
  const next: GalleryState = {
    ...state,
    photos: {
      ...state.photos,
      [id]: { ...photo, deletedAt: now, updatedAt: now },
    },
  };
  return bump(next);
}

export function setOrder(state: GalleryState, order: PhotoId[]): GalleryState {
  const active = new Set(activeOrder(state));
  const filtered = order.filter((id) => active.has(id));
  const missing = activeOrder(state).filter((id) => !filtered.includes(id));
  return bump({ ...state, order: [...filtered, ...missing] });
}

export function upsertPhoto(state: GalleryState, entry: PhotoEntry): GalleryState {
  const exists = state.photos[entry.id];
  const nextPhotos = { ...state.photos, [entry.id]: entry };
  let nextOrder = state.order;
  if (!exists && entry.deletedAt === null) {
    nextOrder = [...state.order, entry.id];
  }
  return bump({ ...state, photos: nextPhotos, order: nextOrder });
}
