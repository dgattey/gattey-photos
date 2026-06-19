import { getMacOSRelease } from "@/lib/macos-release";
import { NextResponse } from "next/server";

export const dynamic = "force-static";

/** Redirects to the zip from committed `server/public/` (baked at deploy time). */
export function GET() {
  const release = getMacOSRelease();
  if (!release) {
    return NextResponse.json(
      { error: "No macOS release is published yet." },
      { status: 404 },
    );
  }
  if (!release.downloadReady) {
    return NextResponse.json(
      { error: "Release is still deploying. Try again in a minute." },
      { status: 503, headers: { "Retry-After": "60" } },
    );
  }
  return NextResponse.redirect(release.downloadUrl, { status: 302 });
}
