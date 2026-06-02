import { emptyGalleryUpdatedAt } from "./gallery-mutation";
import type {
  GalleryState,
  PhotoEntry,
  PhotoId,
  RawPhotoEntry,
  UploaderId,
} from "./types";

export const MANIFEST_PATH = "gallery/manifest.json";
/** Small separate blob holding only the currently shown photo (decoupled from the library catalog). */
export const CURRENT_PATH = "gallery/current.json";

/** Name assigned to photos uploaded before uploader attribution existed. */
export const LEGACY_UPLOADER_NAME = "Dylan";

export function emptyGallery(): GalleryState {
  return {
    updatedAt: emptyGalleryUpdatedAt(),
    order: [],
    photos: {},
    uploaders: {},
    currentPhotoId: null,
  };
}

/**
 * Deterministic uploader id for a pre-uploaderId display name. Stable across reads so
 * in-memory normalization yields the same id every pull until a write bakes it in.
 */
export function legacyUploaderId(name: string): UploaderId {
  const s = name.trim() || LEGACY_UPLOADER_NAME;
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return `u-${(h >>> 0).toString(16).padStart(8, "0")}`;
}

/**
 * Parse raw manifest photos into id-keyed entries plus the uploaders map. Photos written before
 * uploader ids carry a `uploadedBy` string; collapse each distinct name to one deterministic id.
 */
export function coalesceUploaders(
  rawPhotos: Record<PhotoId, RawPhotoEntry>,
  rawUploaders: Record<UploaderId, string> | undefined
): { photos: Record<PhotoId, PhotoEntry>; uploaders: Record<UploaderId, string> } {
  const uploaders: Record<UploaderId, string> = { ...(rawUploaders ?? {}) };
  const photos: Record<PhotoId, PhotoEntry> = {};
  for (const [id, raw] of Object.entries(rawPhotos)) {
    let uploaderId = raw.uploaderId;
    if (!uploaderId) {
      const name = (raw.uploadedBy ?? "").trim() || LEGACY_UPLOADER_NAME;
      uploaderId = legacyUploaderId(name);
      if (!uploaders[uploaderId]) uploaders[uploaderId] = name;
    } else if (!uploaders[uploaderId]) {
      uploaders[uploaderId] = (raw.uploadedBy ?? "").trim() || LEGACY_UPLOADER_NAME;
    }
    photos[id] = {
      id: raw.id,
      filename: raw.filename,
      blobPath: raw.blobPath,
      sizeBytes: raw.sizeBytes,
      updatedAt: raw.updatedAt,
      deletedAt: raw.deletedAt,
      uploaderId,
    };
  }
  return { photos, uploaders };
}

/**
 * Find the uploader id already mapped to `name`, or register `newId` for it. Keeps one id per
 * display name so a person's uploads share an id and a single rename covers them all.
 */
export function ensureUploaderId(
  state: GalleryState,
  name: string,
  newId: UploaderId
): { state: GalleryState; uploaderId: UploaderId } {
  const trimmed = name.trim() || LEGACY_UPLOADER_NAME;
  for (const [id, mapped] of Object.entries(state.uploaders)) {
    if (mapped === trimmed) return { state, uploaderId: id };
  }
  return {
    state: { ...state, uploaders: { ...state.uploaders, [newId]: trimmed } },
    uploaderId: newId,
  };
}

export function activeOrder(state: GalleryState): PhotoId[] {
  return state.order.filter((id) => {
    const p = state.photos[id];
    return p && p.deletedAt === null;
  });
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
  return next;
}

export function setCurrentPhoto(state: GalleryState, id: PhotoId): GalleryState {
  if (!activeOrder(state).includes(id)) return state;
  return { ...state, currentPhotoId: id, currentPhotoUpdatedBy: "manual" };
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
    return { ...state, currentPhotoId: first, currentPhotoUpdatedBy: "cron" };
  }
  const nextId = nextPhotoInOrder(state, current);
  if (!nextId || nextId === current) return state;
  return { ...state, currentPhotoId: nextId, currentPhotoUpdatedBy: "cron" };
}

export function setOrder(state: GalleryState, order: PhotoId[]): GalleryState {
  const active = new Set(activeOrder(state));
  const filtered = order.filter((id) => active.has(id));
  const missing = activeOrder(state).filter((id) => !filtered.includes(id));
  return { ...state, order: [...filtered, ...missing] };
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
    return { state: { ...state, currentPhotoId: null }, dirty: true };
  }
  const current = state.currentPhotoId;
  if (current && active.includes(current)) {
    return { state, dirty: false };
  }
  return { state: { ...state, currentPhotoId: active[0]! }, dirty: true };
}

/** Collapse legacy uploaders into the map and repair `currentPhotoId` before storage. */
export function normalizeManifest(state: GalleryState): GalleryState {
  const { photos, uploaders } = coalesceUploaders(state.photos, state.uploaders);
  return resolveCurrentPhoto({ ...state, photos, uploaders }).state;
}

/** Point every uploader id named `fromName` at `toName` (settings rename). One map write; photos untouched. */
export function renameUploader(
  state: GalleryState,
  fromName: string,
  toName: string
): GalleryState {
  const from = fromName.trim();
  const to = toName.trim();
  if (!from || !to || from === to) return state;

  let dirty = false;
  const uploaders = { ...state.uploaders };
  for (const id of Object.keys(uploaders)) {
    if (uploaders[id] === from) {
      uploaders[id] = to;
      dirty = true;
    }
  }
  if (!dirty) return state;
  return { ...state, uploaders };
}

/** True once no uploader id still maps to `fromName` (manifest-write visibility check). */
export function renameUploaderApplied(
  state: GalleryState,
  fromName: string
): boolean {
  const from = fromName.trim();
  if (!from) return true;
  return !Object.values(state.uploaders).some((name) => name === from);
}

export function upsertPhoto(state: GalleryState, entry: PhotoEntry): GalleryState {
  const exists = state.photos[entry.id];
  const nextPhotos = { ...state.photos, [entry.id]: entry };
  let nextOrder = state.order;
  if (!exists && entry.deletedAt === null) {
    nextOrder = [...state.order, entry.id];
  }
  return { ...state, photos: nextPhotos, order: nextOrder };
}
