import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

function registryKey(): Buffer {
  const secret = process.env.SYNC_PASSWORD;
  if (!secret) {
    throw new Error("SYNC_PASSWORD required to encrypt device tokens");
  }
  return createHash("sha256").update(secret, "utf8").digest();
}

export function encryptDeviceToken(plain: string): string {
  const key = registryKey();
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString("base64url");
}

export function decryptDeviceToken(ciphertext: string): string {
  const key = registryKey();
  const buf = Buffer.from(ciphertext, "base64url");
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const enc = buf.subarray(28);
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString("utf8");
}
