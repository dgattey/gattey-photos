import { assertSessionToken } from "@/lib/auth";

export async function GET(request: Request) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;
  return Response.json({ ok: true });
}
