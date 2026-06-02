import { get, put } from "@vercel/blob";

type BlobAccessMode = "public" | "private";

/** Defaults to private (matches Vercel Blob stores configured as private). Set GATTEY_BLOB_ACCESS=public only for a public store. */
function blobAccess(): BlobAccessMode {
  const raw = process.env.GATTEY_BLOB_ACCESS?.trim().toLowerCase();
  return raw === "public" ? "public" : "private";
}

/// `useCache: false` reads from origin storage instead of the CDN cache (private blobs only), giving
/// read-after-write consistency for the frequently-overwritten manifest. Immutable photo bytes keep the cache.
export async function readBlobBytes(
  pathname: string,
  useCache = true
): Promise<Buffer | null> {
  try {
    const result = await get(pathname, { access: blobAccess(), useCache });
    if (!result || result.statusCode !== 200 || !result.stream) {
      return null;
    }
    return Buffer.from(await new Response(result.stream).arrayBuffer());
  } catch {
    return null;
  }
}

export async function writeBlob(
  pathname: string,
  body: string | Buffer,
  contentType: string,
  cacheControlMaxAge?: number
): Promise<void> {
  await put(pathname, body, {
    access: blobAccess(),
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType,
    ...(cacheControlMaxAge != null ? { cacheControlMaxAge } : {}),
  });
}
