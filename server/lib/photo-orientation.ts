import sharp from "sharp";

export const MAX_PHOTO_PIXEL_SIZE = 4096;

/**
 * Bakes any non-1 EXIF Orientation tag (2..8) into the JPEG pixel buffer, strips
 * the orientation tag, and caps dimensions at 4096px on the longest edge so
 * downstream consumers (such as Bloomin8 e-ink Open API) never render raw sensor
 * scanlines upside down or sideways and cached/uploaded JPEGs stay within bounds.
 */
export async function normalizePhotoOrientation(
  bytes: Buffer,
  maxPixelSize: number = MAX_PHOTO_PIXEL_SIZE
): Promise<Buffer> {
  try {
    const image = sharp(bytes, { failOn: "none" });
    const metadata = await image.metadata();
    const orientation = metadata.orientation;
    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;
    const needsRotate = typeof orientation === "number" && orientation > 1;
    const needsResize = Math.max(width, height) > maxPixelSize;
    if (!needsRotate && !needsResize) {
      return bytes;
    }
    return await image
      .rotate()
      .resize({
        width: maxPixelSize,
        height: maxPixelSize,
        fit: "inside",
        withoutEnlargement: true,
      })
      .keepIccProfile()
      .jpeg({ quality: 92 })
      .toBuffer();
  } catch (err) {
    console.warn("[photo-orientation] failed to inspect/rotate image:", err);
    return bytes;
  }
}
