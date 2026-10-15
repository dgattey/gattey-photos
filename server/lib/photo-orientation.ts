import sharp from "sharp";

/**
 * Bakes any non-1 EXIF Orientation tag (2..8) into the JPEG pixel buffer and strips
 * the orientation tag so downstream consumers (such as Bloomin8 e-ink Open API)
 * never render raw sensor scanlines upside down or sideways.
 */
export async function normalizePhotoOrientation(bytes: Buffer): Promise<Buffer> {
  try {
    const image = sharp(bytes, { failOn: "none" });
    const metadata = await image.metadata();
    const orientation = metadata.orientation;
    if (typeof orientation !== "number" || orientation <= 1) {
      return bytes;
    }
    return await image
      .rotate()
      .keepIccProfile()
      .jpeg({ quality: 92 })
      .toBuffer();
  } catch (err) {
    console.warn("[photo-orientation] failed to inspect/rotate image:", err);
    return bytes;
  }
}
