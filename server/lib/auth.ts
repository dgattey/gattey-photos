import { createHmac, timingSafeEqual } from "node:crypto";
import { get } from "@vercel/edge-config";

/** Omitted or zero = no expiry (family app; invalidate only when SYNC_PASSWORD rotates). */
type SessionPayload = { exp?: number };

async function syncSecret(): Promise<string | null> {
  if (process.env.SYNC_PASSWORD) {
    return process.env.SYNC_PASSWORD;
  }
  if (!process.env.EDGE_CONFIG) {
    return null;
  }
  const fromEdge = await get<string>("syncPassword").catch(() => null);
  return fromEdge ?? null;
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  return header?.startsWith("Bearer ") ? header.slice(7) : null;
}

function base64urlEncode(data: Buffer | string): string {
  const buf = typeof data === "string" ? Buffer.from(data, "utf8") : data;
  return buf.toString("base64url");
}

function base64urlDecode(s: string): Buffer | null {
  try {
    return Buffer.from(s, "base64url");
  } catch {
    return null;
  }
}

export function mintSessionToken(secret: string): string {
  const payloadB64 = base64urlEncode(JSON.stringify({} satisfies SessionPayload));
  const sig = createHmac("sha256", secret).update(payloadB64).digest();
  return `${payloadB64}.${base64urlEncode(sig)}`;
}

export function verifySessionToken(secret: string, token: string): boolean {
  const dot = token.indexOf(".");
  if (dot <= 0) return false;
  const payloadB64 = token.slice(0, dot);
  const sigB64 = token.slice(dot + 1);
  const sig = base64urlDecode(sigB64);
  if (!sig) return false;
  const expected = createHmac("sha256", secret).update(payloadB64).digest();
  if (sig.length !== expected.length || !timingSafeEqual(sig, expected)) {
    return false;
  }
  const payloadRaw = base64urlDecode(payloadB64);
  if (!payloadRaw) return false;
  let payload: SessionPayload;
  try {
    payload = JSON.parse(payloadRaw.toString("utf8")) as SessionPayload;
  } catch {
    return false;
  }
  if (typeof payload.exp === "number" && payload.exp > 0) {
    return payload.exp >= Math.floor(Date.now() / 1000);
  }
  return true;
}

async function tokenMatchesSyncAuth(token: string): Promise<boolean> {
  const secret = await syncSecret();
  if (!secret) return false;
  if (token === secret) return true;
  return verifySessionToken(secret, token);
}

/** Accepts Bearer = sync password or a valid signed session token. */
export async function assertSyncPassword(request: Request): Promise<Response | null> {
  const token = bearerToken(request);
  if (!token) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!(await tokenMatchesSyncAuth(token))) {
    return new Response("Unauthorized", { status: 401 });
  }
  return null;
}

/** Session minting: Bearer must be the sync password only (not an existing session). */
export async function assertPasswordOnly(request: Request): Promise<Response | null> {
  const token = bearerToken(request);
  if (!token) {
    return new Response("Unauthorized", { status: 401 });
  }
  const secret = await syncSecret();
  if (!secret || token !== secret) {
    return new Response("Unauthorized", { status: 401 });
  }
  return null;
}

export async function createSessionResponse(): Promise<Response> {
  const secret = await syncSecret();
  if (!secret) {
    return new Response("Server misconfigured", { status: 500 });
  }
  return Response.json({ ok: true, sessionToken: mintSessionToken(secret) });
}

/** Vercel Cron: `Authorization: Bearer <CRON_SECRET>` when `CRON_SECRET` is set. */
export function assertCronSecret(request: Request): Response | null {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    return new Response("Server misconfigured", { status: 500 });
  }
  const header = request.headers.get("authorization");
  if (header !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  return null;
}
