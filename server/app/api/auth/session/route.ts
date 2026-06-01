import { assertPasswordOnly, createSessionResponse } from "@/lib/auth";

export async function POST(request: Request) {
  const auth = await assertPasswordOnly(request);
  if (auth) return auth;
  return createSessionResponse();
}
