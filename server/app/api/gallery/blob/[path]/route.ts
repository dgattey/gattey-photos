import { assertSessionToken } from "@/lib/auth";
import * as storage from "@/lib/storage";

type Params = { params: Promise<{ path: string }> };

export async function GET(request: Request, { params }: Params) {
  const auth = await assertSessionToken(request);
  if (auth) return auth;

  const { path: encoded } = await params;
  const blobPath = decodeURIComponent(encoded);
  const bytes = await storage.readPhotoBytes(blobPath);
  if (!bytes) {
    return new Response("not found", { status: 404 });
  }
  return new Response(new Uint8Array(bytes), {
    headers: {
      "Content-Type": "image/jpeg",
      "Cache-Control": "private, max-age=3600",
    },
  });
}
