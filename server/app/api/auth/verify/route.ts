import { assertSyncPassword } from "@/lib/auth";

export async function GET(request: Request) {
  const auth = await assertSyncPassword(request);
  if (auth) return auth;
  return Response.json({ ok: true });
}
