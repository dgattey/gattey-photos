import { buildGalleryResponse } from "./gallery-service";
import { jsonApiError, staleGalleryResponse, storageErrorResponse } from "./api-error";
import { StaleGalleryError } from "./manifest-errors";
import type { GalleryState } from "./types";
import * as storage from "./storage";

const EPOCH = "1970-01-01T00:00:00.000Z";

function parseTs(iso: string): number {
  const ms = Date.parse(iso.trim());
  return Number.isFinite(ms) ? ms : 0;
}

export function emptyGalleryUpdatedAt(): string {
  return EPOCH;
}

export function touchGallery(state: GalleryState): GalleryState {
  return { ...state, updatedAt: new Date().toISOString() };
}

function isNewerThan(server: GalleryState, baseUpdatedAt: string): boolean {
  return parseTs(server.updatedAt) > parseTs(baseUpdatedAt);
}

export function parseBaseUpdatedAt(value: unknown): string | Response {
  if (typeof value !== "string" || value.trim().length === 0) {
    return jsonApiError(400, "baseUpdatedAt required");
  }
  return value.trim();
}

/**
 * Optimistic manifest write. Throws `StaleGalleryError` (409) when `baseUpdatedAt`
 * is older than what is on disk. `writeManifest` resolves only once the blob is
 * durably stored and returns the normalized written state, so callers trust that
 * return value instead of re-reading (a re-read goes through the Blob CDN cache and
 * can serve a stale copy of the path we just overwrote).
 */
export async function applyGalleryMutation(
  baseUpdatedAt: string,
  update: (state: GalleryState) => GalleryState
): Promise<GalleryState> {
  const state = await storage.readManifest();
  if (isNewerThan(state, baseUpdatedAt)) {
    throw new StaleGalleryError(state);
  }
  return storage.writeManifest(touchGallery(update(state)));
}

type GalleryRouteInit = { status?: number; cacheControl?: string };

/** Shared try/catch + JSON gallery body for mutation routes. */
export async function respondGalleryMutation(
  request: Request,
  logPrefix: string,
  baseUpdatedAt: string,
  update: (state: GalleryState) => GalleryState,
  init: GalleryRouteInit = {}
): Promise<Response> {
  try {
    const saved = await applyGalleryMutation(baseUpdatedAt, update);
    const gallery = await buildGalleryResponse(request, saved);
    const headers: Record<string, string> = {};
    if (init.cacheControl) headers["Cache-Control"] = init.cacheControl;
    return Response.json(gallery, { status: init.status ?? 200, headers });
  } catch (err) {
    if (err instanceof StaleGalleryError) {
      return staleGalleryResponse(request, err);
    }
    return storageErrorResponse(err, logPrefix);
  }
}
