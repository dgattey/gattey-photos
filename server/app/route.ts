import { isGalleryReachable } from "@/lib/reachability";

const plain = (body: string, status: number) =>
  new Response(body, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });

export async function GET() {
  if (await isGalleryReachable()) {
    return plain("available", 200);
  }
  return plain("unavailable", 503);
}
