const DEFAULT_BASE =
  process.env.BLOOMIN8_OPEN_API_BASE_URL?.trim() ||
  "https://einkshot-349134901638.us-central1.run.app";

export type DeviceStatus = {
  name?: string;
  width?: number;
  height?: number;
  orientation?: string;
  remoteImageOn?: boolean;
  remoteImageInterval?: string;
};

type DeviceStatusResponse = {
  success?: boolean;
  device?: {
    name?: string;
    width?: number;
    height?: number;
    orientation?: string;
    remote_image_on?: boolean;
    remote_image_interval?: string;
  };
  message?: string;
  error?: string;
};

type PushResponse = {
  success?: boolean;
  remote_image_id?: string;
  estimated_push_time?: string;
  error?: string;
  message?: string;
};

function baseURL(custom?: string): string {
  const raw = custom?.trim() || DEFAULT_BASE;
  return raw.replace(/\/$/, "");
}

export async function fetchDeviceStatus(
  token: string,
  openApiBaseURL?: string
): Promise<DeviceStatus> {
  const url = `${baseURL(openApiBaseURL)}/open-api/device/status`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(30_000),
  });
  const data = (await res.json()) as DeviceStatusResponse;
  if (!res.ok || data.success !== true || !data.device) {
    const detail = data.error || data.message || (await res.text().catch(() => ""));
    throw new Error(`Open API ${res.status}: ${detail}`);
  }
  const d = data.device;
  return {
    name: d.name,
    width: d.width,
    height: d.height,
    orientation: d.orientation,
    remoteImageOn: d.remote_image_on,
    remoteImageInterval: d.remote_image_interval,
  };
}

export async function pushImage(
  token: string,
  jpeg: Buffer,
  openApiBaseURL?: string
): Promise<{ remoteImageId?: string; estimatedPushTime?: string }> {
  const boundary = `bloomin8-${crypto.randomUUID()}`;
  const prefix = `--${boundary}\r\nContent-Disposition: form-data; name="image"; filename="photo.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`;
  const suffix = `\r\n--${boundary}--\r\n`;
  const body = Buffer.concat([
    Buffer.from(prefix, "utf8"),
    jpeg,
    Buffer.from(suffix, "utf8"),
  ]);

  const url = `${baseURL(openApiBaseURL)}/open-api/push`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
    },
    body,
    signal: AbortSignal.timeout(120_000),
  });
  const data = (await res.json()) as PushResponse;
  if (!res.ok || !data.success) {
    const detail = data.error || data.message || JSON.stringify(data);
    throw new Error(`Open API push ${res.status}: ${detail}`);
  }
  return {
    remoteImageId: data.remote_image_id,
    estimatedPushTime: data.estimated_push_time,
  };
}
