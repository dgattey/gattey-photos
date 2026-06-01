import { tryReadManifest } from "@/lib/reachability";

export async function GET() {
  const mode =
    process.env.GATTEY_LOCAL_STORAGE === "1" ? "local" : "vercel-blob";
  const state = await tryReadManifest();
  const ok = state !== null;
  const photos = ok
    ? Object.values(state.photos).filter((p) => !p.deletedAt).length
    : -1;
  return Response.json({
    ok,
    mode,
    photos,
    version: process.env.VERCEL ? "production" : "development",
  });
}
