export class ManifestUpdateConflictError extends Error {
  constructor(message = "gallery manifest update conflict after retries") {
    super(message);
    this.name = "ManifestUpdateConflictError";
  }
}
