import { getMacOSRelease } from "@/lib/macos-release";
import { connection } from "next/server";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = "force-no-store";

/** Redirects to the zip named in the live appcast (resolved on each request). */
export async function GET() {
  await connection();
  const release = await getMacOSRelease();
  if (!release) {
    return NextResponse.json(
      { error: "No macOS release is published yet." },
      { status: 404, headers: { "Cache-Control": "no-store" } },
    );
  }
  if (!release.downloadReady) {
    return NextResponse.json(
      { error: "Release is still deploying. Try again in a minute." },
      {
        status: 503,
        headers: { "Cache-Control": "no-store", "Retry-After": "60" },
      },
    );
  }
  return NextResponse.redirect(release.downloadUrl, {
    status: 302,
    headers: { "Cache-Control": "no-store" },
  });
}
