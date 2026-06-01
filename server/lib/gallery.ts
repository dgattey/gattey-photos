import type { GalleryState, PhotoEntry, PhotoId } from "./types";

export const MANIFEST_PATH = "gallery/manifest.json";

/** Backfill value for manifest entries written before uploader attribution. */
export const LEGACY_UPLOADER_NAME = "Dylan";

export function emptyGallery(): GalleryState {
  return { version: 0, order: [], photos: {}, currentPhotoId: null };
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

/** True when soft-deleting `id` would leave at least one active photo. */
export function canSoftDelete(state: GalleryState, id: PhotoId): boolean {
  const photo = state.photos[id];
  if (!photo || photo.deletedAt !== null) return false;
  return activeOrder(state).length > 1;
}

/**
 * After `deletedId` is removed, pick the next active id in gallery order (scan forward,
 * then backward). Uses `before` for index and `after` for the remaining active set.
 */
export function nextCurrentPhotoId(
  before: GalleryState,
  deletedId: PhotoId,
  after: GalleryState
): PhotoId | null {
  const remaining = activeOrder(after);
  if (remaining.length === 0) return null;
  const idx = before.order.indexOf(deletedId);
  if (idx === -1) return remaining[0] ?? null;
  for (let i = idx + 1; i < before.order.length; i++) {
    const candidate = before.order[i];
    if (remaining.includes(candidate)) return candidate;
  }
  for (let i = idx - 1; i >= 0; i--) {
    const candidate = before.order[i];
    if (remaining.includes(candidate)) return candidate;
  }
  return remaining[0] ?? null;
}

export function softDelete(state: GalleryState, id: PhotoId): GalleryState | null {
  const photo = state.photos[id];
  if (!photo || photo.deletedAt) return state;
  if (!canSoftDelete(state, id)) return null;
  const now = new Date().toISOString();
  let next: GalleryState = {
    ...state,
    photos: {
      ...state.photos,
      [id]: { ...photo, deletedAt: now, updatedAt: now },
    },
  };
  if (next.currentPhotoId === id) {
    next = { ...next, currentPhotoId: nextCurrentPhotoId(state, id, next) };
  }
  return bump(next);
}

export function setCurrentPhoto(state: GalleryState, id: PhotoId): GalleryState {
  if (!activeOrder(state).includes(id)) return state;
  return bump({ ...state, currentPhotoId: id, currentPhotoUpdatedBy: "manual" });
}

/** Next active id in manifest `order` after `current`, wrapping at end. */
export function nextPhotoInOrder(state: GalleryState, current: PhotoId): PhotoId | null {
  const active = new Set(activeOrder(state));
  if (active.size === 0) return null;
  const idx = state.order.indexOf(current);
  if (idx === -1) {
    for (const id of state.order) {
      if (active.has(id)) return id;
    }
    return null;
  }
  for (let i = 1; i <= state.order.length; i++) {
    const candidate = state.order[(idx + i) % state.order.length]!;
    if (active.has(candidate)) return candidate;
  }
  return null;
}

/** First active photo id in manifest `order`. */
export function firstActiveInOrder(state: GalleryState): PhotoId | null {
  const active = new Set(activeOrder(state));
  for (const id of state.order) {
    if (active.has(id)) return id;
  }
  return null;
}

/** Scheduled advance: move `currentPhotoId` to the next active entry in `order`. */
export function advanceCurrentPhoto(state: GalleryState): GalleryState {
  const active = activeOrder(state);
  if (active.length === 0) return state;
  const current = state.currentPhotoId;
  if (!current || !active.includes(current)) {
    const first = firstActiveInOrder(state);
    if (!first) return state;
    return bump({ ...state, currentPhotoId: first, currentPhotoUpdatedBy: "cron" });
  }
  const nextId = nextPhotoInOrder(state, current);
  if (!nextId || nextId === current) return state;
  return bump({ ...state, currentPhotoId: nextId, currentPhotoUpdatedBy: "cron" });
}

export function setOrder(state: GalleryState, order: PhotoId[]): GalleryState {
  const active = new Set(activeOrder(state));
  const filtered = order.filter((id) => active.has(id));
  const missing = activeOrder(state).filter((id) => !filtered.includes(id));
  return bump({ ...state, order: [...filtered, ...missing] });
}

/**
 * Ensures `currentPhotoId` is null when empty, or the first active id in `order`
 * when missing or invalid (matches macOS `withResolvedCurrentPhoto`).
 */
export function resolveCurrentPhoto(state: GalleryState): {
  state: GalleryState;
  dirty: boolean;
} {
  const active = activeOrder(state);
  if (active.length === 0) {
    if (state.currentPhotoId == null) {
      return { state, dirty: false };
    }
    return { state: bump({ ...state, currentPhotoId: null }), dirty: true };
  }
  const current = state.currentPhotoId;
  if (current && active.includes(current)) {
    return { state, dirty: false };
  }
  return { state: bump({ ...state, currentPhotoId: active[0]! }), dirty: true };
}

/** Backfill `uploadedBy` and repair `currentPhotoId`; returns whether persistence is needed. */
export function normalizeManifest(state: GalleryState): {
  state: GalleryState;
  dirty: boolean;
} {
  let next = state;
  let dirty = false;
  const photos = { ...next.photos };
  for (const id of Object.keys(photos)) {
    const photo = photos[id]!;
    if (!photo.uploadedBy) {
      photos[id] = { ...photo, uploadedBy: LEGACY_UPLOADER_NAME };
      dirty = true;
    }
  }
  if (dirty) {
    next = { ...next, photos };
  }
  const resolved = resolveCurrentPhoto(next);
  return {
    state: resolved.state,
    dirty: dirty || resolved.dirty,
  };
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
