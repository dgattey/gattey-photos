import sharp from "sharp";

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
  try {
    const metadata = await sharp(bytes, { failOn: "none" }).metadata();
    const orientation = metadata.orientation;
    if (typeof orientation !== "number" || orientation <= 1) {
      return { bytes, didRotate: false };
    }
    const rotated = await sharp(bytes, { failOn: "none" })
      .rotate()
      .jpeg({ quality: 92 })
      .toBuffer();
    return { bytes: rotated, didRotate: true };
  } catch (err) {
    console.warn("[photo-orientation] failed to inspect/rotate image:", err);
    return { bytes, didRotate: false };
  }
}
