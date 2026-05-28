import { get } from "@vercel/edge-config";

export async function assertSyncPassword(request: Request): Promise<Response | null> {
  const header = request.headers.get("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    return new Response("Unauthorized", { status: 401 });
  }

  const expected =
    process.env.SYNC_PASSWORD ??
    (process.env.EDGE_CONFIG
      ? await get<string>("syncPassword").catch(() => null)
      : null);

  if (!expected || token !== expected) {
    return new Response("Unauthorized", { status: 401 });
  }
  return null;
}
