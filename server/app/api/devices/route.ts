import { assertSessionToken } from "@/lib/auth";
import { listDevices, registerDevice } from "@/lib/devices/registry";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;
  const owner = new URL(request.url).searchParams.get("owner");
  const devices = await listDevices(owner);
  return Response.json({ devices });
}

export async function POST(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const body = (await request.json()) as {
    setupText?: string;
    displayName?: string;
    registeredBy?: string;
  };
  if (!body.setupText || typeof body.setupText !== "string") {
    return new Response("setupText required", { status: 400 });
  }

  try {
    const device = await registerDevice({
      setupText: body.setupText,
      displayName: body.displayName,
      registeredBy:
        typeof body.registeredBy === "string" && body.registeredBy.trim()
          ? body.registeredBy.trim()
          : "Unknown",
    });
    return Response.json({ device }, { status: 201 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "register failed";
    return new Response(msg, { status: 400 });
  }
}
