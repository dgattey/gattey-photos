export type PhotoId = string;

export interface PhotoEntry {
  id: PhotoId;
  filename: string;
  blobPath: string;
  sizeBytes: number;
  updatedAt: string;
  deletedAt: string | null;
}

export interface GalleryState {
  version: number;
  order: PhotoId[];
  photos: Record<PhotoId, PhotoEntry>;
}

export interface GalleryPhotoView extends PhotoEntry {
  downloadUrl: string;
}

export interface GalleryResponse {
  state: GalleryState;
  photos: GalleryPhotoView[];
}
