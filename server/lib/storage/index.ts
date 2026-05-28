import type { GalleryState } from "../types";

const useLocal = () => process.env.GATTEY_LOCAL_STORAGE === "1";

export async function readManifest(): Promise<GalleryState> {
  if (useLocal()) {
    const local = await import("./local");
    return local.readManifest();
  }
  const blob = await import("./blob");
  return blob.readManifest();
}

export async function writeManifest(state: GalleryState): Promise<void> {
  if (useLocal()) {
    const local = await import("./local");
    return local.writeManifest(state);
  }
  const blob = await import("./blob");
  return blob.writeManifest(state);
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

export async function resolveDownloadUrl(
  request: Request,
  blobPath: string
): Promise<string | null> {
  if (useLocal()) {
    const local = await import("./local");
    const bytes = await local.getBytes(blobPath);
    if (!bytes) return null;
    return local.localDownloadUrl(request, blobPath);
  }
  const blob = await import("./blob");
  return blob.getBytesUrl(blobPath);
}

export async function readPhotoBytes(blobPath: string): Promise<Buffer | null> {
  if (useLocal()) {
    const local = await import("./local");
    return local.getBytes(blobPath);
  }
  const meta = await import("./blob");
  const url = await meta.getBytesUrl(blobPath);
  if (!url) return null;
  const res = await fetch(url);
  if (!res.ok) return null;
  return Buffer.from(await res.arrayBuffer());
}
