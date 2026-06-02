import { normalizeManifest } from "../gallery";
import { emptyGalleryUpdatedAt } from "../gallery-mutation";
import type { GalleryState } from "../types";

const useLocal = () => process.env.GATTEY_LOCAL_STORAGE === "1";

async function readRawManifest(): Promise<GalleryState> {
  if (useLocal()) {
    const local = await import("./local");
    return local.readManifest();
  }
  const blob = await import("./blob");
  return blob.readManifest();
}

export async function readManifest(): Promise<GalleryState> {
  const raw = await readRawManifest();
  let state: GalleryState = {
    updatedAt: raw.updatedAt?.trim() || emptyGalleryUpdatedAt(),
    order: raw.order ?? [],
    photos: raw.photos ?? {},
    currentPhotoId: raw.currentPhotoId ?? null,
    currentPhotoUpdatedBy: raw.currentPhotoUpdatedBy,
  };
  const { state: normalized, dirty: normalizedDirty } = normalizeManifest(state);
  state = normalized;
  if (normalizedDirty) {
    return writeManifest(state);
  }
  return state;
}

/** Persist manifest after normalization; returns the stored state (API responses must use this). */
export async function writeManifest(state: GalleryState): Promise<GalleryState> {
  const { state: normalized } = normalizeManifest(state);
  if (useLocal()) {
    const local = await import("./local");
    await local.writeManifest(normalized);
    return normalized;
  }
  const blob = await import("./blob");
  await blob.writeManifest(normalized);
  return normalized;
}

export async function putPhotoBytes(
  blobPath: string,
  bytes: Buffer
): Promise<string> {
  if (useLocal()) {
    const local = await import("./local");
    await local.putBytes(blobPath, bytes);
    return blobPath;
  }
  const blob = await import("./blob");
  return blob.putBytes(blobPath, bytes);
}

/** Local dev only; production serves bytes via `/api/gallery/photos/[id]/image`. */
export async function resolveDownloadUrl(
  request: Request,
  blobPath: string
): Promise<string | null> {
  if (!useLocal()) return null;
  const local = await import("./local");
  const bytes = await local.getBytes(blobPath);
  if (!bytes) return null;
  return local.localDownloadUrl(request, blobPath);
}

export async function readPhotoBytes(blobPath: string): Promise<Buffer | null> {
  if (useLocal()) {
    const local = await import("./local");
    return local.getBytes(blobPath);
  }
  const blob = await import("./blob");
  return blob.readPhotoBytes(blobPath);
}
