import { coalesceUploaders, resolveCurrentPhoto } from "../gallery";
import { emptyGalleryUpdatedAt } from "../gallery-mutation";
import type {
  CurrentManifest,
  GalleryState,
  RawCurrent,
  RawManifest,
} from "../types";

const useLocal = () => process.env.GATTEY_LOCAL_STORAGE === "1";

async function readLibraryRaw(): Promise<RawManifest> {
  if (useLocal()) {
    const local = await import("./local");
    return local.readManifest();
  }
  const blob = await import("./blob");
  return blob.readManifest();
}

async function readCurrentRaw(): Promise<RawCurrent | null> {
  if (useLocal()) {
    const local = await import("./local");
    return local.readCurrent();
  }
  const blob = await import("./blob");
  return blob.readCurrent();
}

/** Merge the library catalog with the separately-stored current photo, then validate current. */
function assemble(rawLib: RawManifest, rawCurrent: RawCurrent | null): GalleryState {
  const { photos, uploaders } = coalesceUploaders(rawLib.photos ?? {}, rawLib.uploaders);
  const state: GalleryState = {
    updatedAt: rawLib.updatedAt?.trim() || emptyGalleryUpdatedAt(),
    order: rawLib.order ?? [],
    photos,
    uploaders,
    currentPhotoId: rawCurrent?.currentPhotoId ?? null,
    currentPhotoUpdatedBy: rawCurrent?.currentPhotoUpdatedBy ?? null,
  };
  return resolveCurrentPhoto(state).state;
}

/** Assembled gallery (library catalog + current photo). Reads from origin, no CDN cache. */
export async function readManifest(): Promise<GalleryState> {
  const [lib, current] = await Promise.all([readLibraryRaw(), readCurrentRaw()]);
  return assemble(lib, current);
}

/** Catalog version only (one blob read) for the conditional-GET ETag, so a 304 is a single op. */
export async function readGalleryVersion(): Promise<string> {
  const lib = await readLibraryRaw();
  return lib.updatedAt?.trim() || emptyGalleryUpdatedAt();
}

/** Sync token (one blob read) for cheap client polling. Falls back to assembled state until first write. */
export async function readCurrent(): Promise<CurrentManifest> {
  const raw = await readCurrentRaw();
  if (raw && raw.galleryVersion !== undefined) {
    return {
      galleryVersion: raw.galleryVersion?.trim() || emptyGalleryUpdatedAt(),
      currentPhotoId: raw.currentPhotoId ?? null,
      currentPhotoUpdatedBy: raw.currentPhotoUpdatedBy ?? null,
      updatedAt: raw.updatedAt?.trim() || emptyGalleryUpdatedAt(),
    };
  }
  const state = await readManifest();
  return {
    galleryVersion: state.updatedAt,
    currentPhotoId: state.currentPhotoId ?? null,
    currentPhotoUpdatedBy: state.currentPhotoUpdatedBy ?? null,
    updatedAt: state.updatedAt,
  };
}

/** Persist the library catalog only; `currentPhotoId` is owned by `writeCurrent`. Returns assembled state. */
export async function writeManifest(state: GalleryState): Promise<GalleryState> {
  const { photos, uploaders } = coalesceUploaders(state.photos, state.uploaders);
  const library: RawManifest = {
    updatedAt: state.updatedAt,
    order: state.order,
    photos,
    uploaders,
  };
  if (useLocal()) {
    const local = await import("./local");
    await local.writeManifest(library);
  } else {
    const blob = await import("./blob");
    await blob.writeManifest(library);
  }
  return resolveCurrentPhoto({ ...state, photos, uploaders }).state;
}

/** Persist only the currently shown photo (cron rotate / manual set). */
export async function writeCurrent(current: CurrentManifest): Promise<CurrentManifest> {
  if (useLocal()) {
    const local = await import("./local");
    await local.writeCurrent(current);
  } else {
    const blob = await import("./blob");
    await blob.writeCurrent(current);
  }
  return current;
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
