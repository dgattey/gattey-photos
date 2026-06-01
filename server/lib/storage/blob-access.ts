import { get, put } from "@vercel/blob";

export type BlobAccessMode = "public" | "private";

/** Defaults to private (matches Vercel Blob stores configured as private). Set GATTEY_BLOB_ACCESS=public only for a public store. */
export function blobAccess(): BlobAccessMode {
  const raw = process.env.GATTEY_BLOB_ACCESS?.trim().toLowerCase();
  return raw === "public" ? "public" : "private";
}

export async function readBlobBytes(pathname: string): Promise<Buffer | null> {
  try {
    const result = await get(pathname, { access: blobAccess() });
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
  contentType: string
): Promise<void> {
  await put(pathname, body, {
    access: blobAccess(),
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType,
  });
}
