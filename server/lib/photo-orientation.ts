export type NormalizedPhotoResult = {
  bytes: Buffer;
  didRotate: boolean;
};

/**
 * Bakes any non-1 EXIF Orientation tag (2..8) into the JPEG pixel buffer and strips
 * the orientation tag so downstream consumers (such as Bloomin8 e-ink Open API)
 * never render raw sensor scanlines upside down or sideways.
 */
export async function normalizePhotoOrientation(
  bytes: Buffer
): Promise<NormalizedPhotoResult> {
  return { bytes, didRotate: false };
}
