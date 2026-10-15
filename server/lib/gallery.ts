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

/** Fallback display name when an uploader id has no mapped name. */
export const DEFAULT_UPLOADER_NAME = "Dylan";

/** Deterministic FNV-1a uploader id for a display name; assigns one id per person on first upload. */
export function uploaderIdForName(name: string): UploaderId {
  const s = name.trim() || DEFAULT_UPLOADER_NAME;
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return `u-${(h >>> 0).toString(16).padStart(8, "0")}`;
}

const BECCA_UPLOADER_NAME = "Becca";
const MERGED_BECCA_WINDOW_START = "2026-08-30T00:00:00.000Z";
const MERGED_BECCA_WINDOW_END = "2026-09-09T00:00:00.000Z";

/** One-time migration for the Aug 30 – Sep 8, 2026 default-uploader ("Dylan" → "Becca") manifest collision. */
function repairMergedDefaultUploader(
  photos: Record<PhotoId, PhotoEntry>,
  uploaders: Record<UploaderId, string>
): void {
  const dylanId = uploaderIdForName(DEFAULT_UPLOADER_NAME);
  const beccaId = uploaderIdForName(BECCA_UPLOADER_NAME);
  if (uploaders[dylanId] === BECCA_UPLOADER_NAME) {
    uploaders[dylanId] = DEFAULT_UPLOADER_NAME;
  }
  let movedBeccaPhoto = false;
  for (const photo of Object.values(photos)) {
    if (
      photo.deletedAt === null &&
      photo.uploaderId === dylanId &&
      photo.updatedAt >= MERGED_BECCA_WINDOW_START &&
      photo.updatedAt < MERGED_BECCA_WINDOW_END
    ) {
      photo.uploaderId = beccaId;
      movedBeccaPhoto = true;
    }
  }
  if (movedBeccaPhoto && !uploaders[beccaId]) {
    uploaders[beccaId] = BECCA_UPLOADER_NAME;
  }
}

/** Parse raw manifest photos into id-keyed entries and ensure every uploader id has a mapped name. */
export function coalesceUploaders(
  rawPhotos: Record<PhotoId, RawPhotoEntry>,
  rawUploaders: Record<UploaderId, string> | undefined
): { photos: Record<PhotoId, PhotoEntry>; uploaders: Record<UploaderId, string> } {
  const uploaders: Record<UploaderId, string> = { ...(rawUploaders ?? {}) };
  const photos: Record<PhotoId, PhotoEntry> = {};
  for (const [id, raw] of Object.entries(rawPhotos)) {
    const uploaderId = raw.uploaderId ?? uploaderIdForName(DEFAULT_UPLOADER_NAME);
    if (!uploaders[uploaderId]) uploaders[uploaderId] = DEFAULT_UPLOADER_NAME;
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
  repairMergedDefaultUploader(photos, uploaders);
  return { photos, uploaders };
}

/**
 * Find the uploader id already mapped to `name`, or register `newId` for it. Keeps one id per
 * display name so a person's uploads share an id and a single rename covers them all. Never
 * overwrites an existing uploader id that is already mapped to a different display name.
 */
export function ensureUploaderId(
  state: GalleryState,
  name: string,
  newId: UploaderId
): { state: GalleryState; uploaderId: UploaderId } {
  const trimmed = name.trim() || DEFAULT_UPLOADER_NAME;
  if (state.uploaders[newId] === trimmed) {
    return { state, uploaderId: newId };
  }
  for (const [id, mapped] of Object.entries(state.uploaders)) {
    if (mapped === trimmed) return { state, uploaderId: id };
  }
  let targetId = newId;
  if (state.uploaders[targetId] !== undefined && state.uploaders[targetId] !== trimmed) {
    let suffix = 2;
    while (
      state.uploaders[`${newId}-${suffix}`] !== undefined &&
      state.uploaders[`${newId}-${suffix}`] !== trimmed
    ) {
      suffix += 1;
    }
    targetId = `${newId}-${suffix}`;
  }
  return {
    state: { ...state, uploaders: { ...state.uploaders, [targetId]: trimmed } },
    uploaderId: targetId,
  };
}

function activeOrder(state: GalleryState): PhotoId[] {
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
function nextCurrentPhotoId(
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
function nextPhotoInOrder(state: GalleryState, current: PhotoId): PhotoId | null {
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
function firstActiveInOrder(state: GalleryState): PhotoId | null {
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

/** Point every uploader id named `fromName` at `toName` (settings rename). No-op if `toName` is already used by another uploader. */
export function renameUploader(
  state: GalleryState,
  fromName: string,
  toName: string
): GalleryState {
  const from = fromName.trim();
  const to = toName.trim();
  if (!from || !to || from === to) return state;

  const toLower = to.toLowerCase();
  const fromLower = from.toLowerCase();
  if (toLower !== fromLower) {
    const targetExistsElsewhere = Object.values(state.uploaders).some(
      (name) => name !== from && name.trim().toLowerCase() === toLower
    );
    if (targetExistsElsewhere) return state;
  }

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

export function upsertPhoto(state: GalleryState, entry: PhotoEntry): GalleryState {
  const exists = state.photos[entry.id];
  const nextPhotos = { ...state.photos, [entry.id]: entry };
  let nextOrder = state.order;
  if (!exists && entry.deletedAt === null) {
    nextOrder = [...state.order, entry.id];
  }
  return { ...state, photos: nextPhotos, order: nextOrder };
}
