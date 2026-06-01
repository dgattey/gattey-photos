import { assertSessionToken } from "@/lib/auth";
import { fetchDeviceStatus } from "@/lib/bloomin8/open-api";
import { listDevicesDecrypted, toPublicDevice } from "@/lib/devices/registry";
import type { DeviceLiveStatus } from "@/lib/types";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const devices = await listDevicesDecrypted();
  const statuses: DeviceLiveStatus[] = await Promise.all(
    devices.map(async (device) => {
      const pub = toPublicDevice(device);
      try {
        const live = await fetchDeviceStatus(device.token, device.openApiBaseURL);
        return {
          id: device.id,
          displayName: device.displayName,
          reachable: true,
          name: live.name,
          width: live.width,
          height: live.height,
          orientation: live.orientation,
          remoteImageOn: live.remoteImageOn,
          remoteImageInterval: live.remoteImageInterval,
          lastPushAt: pub.lastPushAt,
          lastPushError: pub.lastPushError,
        } satisfies DeviceLiveStatus;
      } catch {
        return {
          id: device.id,
          displayName: device.displayName,
          reachable: false,
          lastPushAt: pub.lastPushAt,
          lastPushError: pub.lastPushError,
        } satisfies DeviceLiveStatus;
      }
    })
  );

  return Response.json({ devices: statuses });
}
