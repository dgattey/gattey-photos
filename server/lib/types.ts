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
  version: number;
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
