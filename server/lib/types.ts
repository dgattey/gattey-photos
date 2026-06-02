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

/** Manifest photo as read from storage; may carry the pre-uploaderId `uploadedBy` string. */
export type RawPhotoEntry = Omit<PhotoEntry, "uploaderId"> & {
  uploaderId?: UploaderId;
  uploadedBy?: string;
};

/** Manifest JSON as read from storage, before boundary normalization into `GalleryState`. */
export interface RawManifest {
  updatedAt?: string;
  order?: PhotoId[];
  photos?: Record<PhotoId, RawPhotoEntry>;
  uploaders?: Record<UploaderId, string>;
  currentPhotoId?: PhotoId | null;
  currentPhotoUpdatedBy?: "cron" | "manual" | null;
}

export interface GalleryPhotoView extends PhotoEntry {
  downloadUrl: string;
}

export interface GalleryResponse {
  state: GalleryState;
  photos: GalleryPhotoView[];
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
