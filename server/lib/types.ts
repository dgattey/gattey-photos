export type PhotoId = string;

export interface PhotoEntry {
  id: PhotoId;
  filename: string;
  blobPath: string;
  sizeBytes: number;
  updatedAt: string;
  deletedAt: string | null;
  /** Display name of the family member who uploaded this photo. */
  uploadedBy: string;
}

export interface GalleryState {
  /** ISO-8601; bumped on every manifest mutation. Clients send this as `baseUpdatedAt`. */
  updatedAt: string;
  order: PhotoId[];
  photos: Record<PhotoId, PhotoEntry>;
  /** Photo the Bloomin8 device is showing. */
  currentPhotoId?: PhotoId | null;
  /** How `currentPhotoId` last changed (for client activity log on pull). */
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
