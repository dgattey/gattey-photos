import { listDevicesDecrypted, recordDevicePushResults } from "../devices/registry";
import { normalizePhotoOrientation } from "../photo-orientation";
import type { GalleryState } from "../types";
import * as storage from "../storage";
import { pushImage } from "./open-api";

export type DevicePushSummary = {
  registered: number;
  pushed: number;
  failed: number;
  failures: Array<{ deviceId: string; displayName: string; error: string }>;
};

export async function pushCurrentPhotoToAllDevices(
  state: GalleryState
): Promise<DevicePushSummary> {
  const summary: DevicePushSummary = {
    registered: 0,
    pushed: 0,
    failed: 0,
    failures: [],
  };

  const photo = state.currentPhotoId ? state.photos[state.currentPhotoId] : undefined;
  if (!photo || photo.deletedAt) {
    return summary;
  }

  const rawBytes = await storage.readPhotoBytes(photo.blobPath);
  if (!rawBytes?.length) {
    console.error("[device-push] missing JPEG for", photo.blobPath);
    return summary;
  }

  const devices = await listDevicesDecrypted();
  summary.registered = devices.length;
  if (devices.length === 0) {
    return summary;
  }

  const bytes = await normalizePhotoOrientation(rawBytes);

  const outcomes = await Promise.all(
    devices.map(async (device) => {
      try {
        await pushImage(device.token, bytes, device.openApiBaseURL);
        summary.pushed += 1;
        return { id: device.id, ok: true as const };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(`[device-push] offline or failed: ${device.displayName}: ${msg}`);
        summary.failed += 1;
        summary.failures.push({
          deviceId: device.id,
          displayName: device.displayName,
          error: msg,
        });
        return { id: device.id, ok: false as const, error: msg };
      }
    })
  );

  // One registry write for the whole batch (skipped when no error state flips),
  // instead of an advanced Blob `put` per frame on every rotation.
  await recordDevicePushResults(outcomes);

  if (summary.pushed > 0) {
    console.info(
      `[device-push] queued on ${summary.pushed}/${summary.registered} frame(s) for photo ${photo.id}`
    );
  } else if (summary.registered > 0) {
    console.warn(
      `[device-push] manifest saved but no frame accepted push (${summary.failed} failed)`
    );
  }

  return summary;
}
