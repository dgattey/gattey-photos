export type PhotoId = string;
export type UploaderId = string;

export interface PhotoEntry {
  id: PhotoId;
  filename: string;
  blobPath: string;
  sizeBytes: number;
  updatedAt: string;
  deletedAt: string | null;
  /** Stable id of the family member who uploaded this; resolves to a name via `GalleryState.uploaders`. */
  uploaderId: UploaderId;
}

export interface GalleryState {
  /** ISO-8601; bumped on every manifest mutation. Clients send this as `baseUpdatedAt`. */
  updatedAt: string;
  order: PhotoId[];
  photos: Record<PhotoId, PhotoEntry>;
  /** Uploader id → current display name. Renaming a person updates one entry here, not every photo. */
  uploaders: Record<UploaderId, string>;
  /** Photo the Bloomin8 device is showing. */
  currentPhotoId?: PhotoId | null;
  /** How `currentPhotoId` last changed (for client activity log on pull). */
  currentPhotoUpdatedBy?: "cron" | "manual" | null;
}

/** Manifest photo as read from storage. `uploaderId` is optional only to guard a malformed blob. */
export type RawPhotoEntry = Omit<PhotoEntry, "uploaderId"> & {
  uploaderId?: UploaderId;
};

/**
 * Library blob JSON (the photo catalog). `currentPhotoId` lives in `CurrentManifest`, not here, so
 * the cron can rotate the shown photo without rewriting this blob or bumping its `updatedAt`.
 */
export interface RawManifest {
  updatedAt?: string;
  order?: PhotoId[];
  photos?: Record<PhotoId, RawPhotoEntry>;
  uploaders?: Record<UploaderId, string>;
}

/**
 * Tiny sync-token blob. Clients poll this single blob: `galleryVersion` (the catalog `updatedAt`)
 * tells them whether to do a full catalog pull, and `currentPhotoId` carries cron rotations. Written
 * by every catalog mutation (with the new version) and by cron / manual "set current".
 */
export interface CurrentManifest {
  galleryVersion: string;
  currentPhotoId: PhotoId | null;
  currentPhotoUpdatedBy: "cron" | "manual" | null;
  updatedAt: string;
}

export type RawCurrent = Partial<CurrentManifest>;

export interface GalleryResponse {
  state: GalleryState;
}

export interface RegisteredDevice {
  id: string;
  displayName: string;
  tokenCiphertext: string;
  openApiBaseURL: string;
  registeredBy: string;
  registeredAt: string;
  lastPushAt?: string;
  lastPushError?: string;
}

export interface RegisteredDevicePublic {
  id: string;
  displayName: string;
  registeredBy: string;
  registeredAt: string;
  lastPushAt?: string;
  lastPushError?: string;
}

export interface DeviceRegistry {
  version: number;
  devices: RegisteredDevice[];
}

export interface DeviceLiveStatus {
  id: string;
  displayName: string;
  registeredBy?: string;
  reachable: boolean;
  name?: string;
  width?: number;
  height?: number;
  orientation?: string;
  remoteImageOn?: boolean;
  remoteImageInterval?: string;
  lastPushAt?: string;
  lastPushError?: string;
}
