import * as storage from "@/lib/storage";

export async function GET() {
  const mode =
    process.env.GATTEY_LOCAL_STORAGE === "1" ? "local" : "vercel-blob";
  let photos = 0;
  try {
    const state = await storage.readManifest();
    photos = Object.values(state.photos).filter((p) => !p.deletedAt).length;
  } catch {
    photos = -1;
  }
  return Response.json({
    ok: true,
    mode,
    photos,
    version: process.env.VERCEL ? "production" : "development",
  });
}
