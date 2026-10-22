import { getMacOSRelease } from "@/lib/macos-release";
import { NextResponse } from "next/server";

export const revalidate = 60;

/** Redirects to the zip named in the latest GitHub release's appcast. */
export async function GET() {
  const release = await getMacOSRelease();
  if (!release) {
    return NextResponse.json(
      { error: "No macOS release is published yet." },
      { status: 404 },
    );
  }
  return NextResponse.redirect(release.downloadUrl, { status: 302 });
}
