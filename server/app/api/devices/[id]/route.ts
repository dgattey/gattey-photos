import { assertSyncPassword } from "@/lib/auth";
import { removeDevice } from "@/lib/devices/registry";

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> }
) {
  const auth = await assertSyncPassword(_request);
  if (auth) return auth;

  const { id } = await context.params;
  const removed = await removeDevice(id);
  if (!removed) {
    return new Response("not found", { status: 404 });
  }
  return new Response(null, { status: 204 });
}
