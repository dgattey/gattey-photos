import { getMacOSRelease } from "@/lib/macos-release";
import { notFound, redirect } from "next/navigation";

export const dynamic = "force-dynamic";

/** Always redirects to the zip named in the current appcast (avoids stale static links). */
export async function GET() {
  const release = getMacOSRelease();
  if (!release) notFound();
  redirect(release.zipPath);
}
