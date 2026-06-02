import { buildGalleryResponse } from "./gallery-service";
import { jsonApiError, staleGalleryResponse, storageErrorResponse } from "./api-error";
import {
  ManifestUpdateConflictError,
  StaleGalleryError,
} from "./manifest-errors";
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

/** Atomic manifest write; 409 when `baseUpdatedAt` is older than on disk. */
export async function applyGalleryMutation(
  baseUpdatedAt: string,
  update: (state: GalleryState) => GalleryState,
  isApplied: (state: GalleryState) => boolean,
  maxAttempts = 10
): Promise<GalleryState> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const state = await storage.readManifest();
    if (isNewerThan(state, baseUpdatedAt)) {
      throw new StaleGalleryError(state);
    }
    const next = touchGallery(update(state));
    await storage.writeManifest(next);
    const verify = await storage.readManifest();
    if (isApplied(verify) && parseTs(verify.updatedAt) >= parseTs(next.updatedAt)) {
      return verify;
    }
    console.warn(
      `[gallery] write not visible (attempt ${attempt + 1}/${maxAttempts})`
    );
  }
  throw new ManifestUpdateConflictError();
}

type GalleryRouteInit = { status?: number; cacheControl?: string };

/** Shared try/catch + JSON gallery body for mutation routes. */
export async function respondGalleryMutation(
  request: Request,
  logPrefix: string,
  baseUpdatedAt: string,
  update: (state: GalleryState) => GalleryState,
  isApplied: (state: GalleryState) => boolean,
  init: GalleryRouteInit = {}
): Promise<Response> {
  try {
    const saved = await applyGalleryMutation(baseUpdatedAt, update, isApplied);
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
