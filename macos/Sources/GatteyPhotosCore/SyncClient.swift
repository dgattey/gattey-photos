import Foundation

public enum SyncError: Error, LocalizedError {
    case badURL(String)
    case http(SyncHTTPFailure)
    case decode
    case missingSyncAuth
    case stale(GalleryResponse)

    public var errorDescription: String? {
        switch self {
        case .badURL(let baseURL):
            return ServerConnectivityCopy.serverDown(at: baseURL)
        case .http(let failure):
            return failure.shortSummary
        case .decode:
            return "Could not decode server response"
        case .missingSyncAuth:
            return "Unlock the gallery to sync (session not set)"
        case .stale:
            return "Gallery changed on server; refreshing and retrying"
        }
    }

    public var activityLogDetail: String? {
        switch self {
        case .http(let failure):
            return failure.activityLogDetail
        case .badURL(let baseURL):
            return ServerConnectivityCopy.serverDown(at: baseURL)
        case .decode:
            return "Could not decode server response"
        case .missingSyncAuth:
            return "Unlock the gallery to sync (session not set)"
        case .stale:
            return "HTTP 409 gallery stale"
        }
    }
}

private struct StaleGalleryPayload: Codable {
    var error: String?
    var state: GalleryState
}

private actor ImageDownloadDeduplicator {
    static let shared = ImageDownloadDeduplicator()
    private var inFlight: [String: Task<Void, Error>] = [:]

    func run(key: String, operation: @escaping @Sendable () async throws -> Void) async throws {
        if let existing = inFlight[key] {
            try await existing.value
            return
        }
        let task = Task {
            try await operation()
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        try await task.value
    }
}

public struct SyncClient: Sendable {
    public var baseURL: URL
    public var bearer: String
    private let session: URLSession

    public init(settings: AppSettings, session: URLSession = .shared) throws {
        let base = settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: base) else {
            throw SyncError.badURL(base)
        }
        guard let bearer = settings.syncBearer else {
            throw SyncError.missingSyncAuth
        }
        self.baseURL = url
        self.bearer = bearer
        self.session = session
    }

    private func request(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        context: String? = nil
    ) async throws -> Data {
        var req = makeRequest(path: path, method: method, contentType: contentType)
        if let body { req.httpBody = body }
        let url = req.url ?? baseURL
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else {
            throw SyncError.http(SyncHTTPFailure(
                statusCode: -1,
                method: method,
                url: url.absoluteString,
                responseBody: "no response",
                requestBodyBytes: body?.count,
                context: context
            ))
        }
        if http.statusCode == 409,
           let payload = try? JSONDecoder().decode(StaleGalleryPayload.self, from: data)
        {
            throw SyncError.stale(GalleryResponse(state: payload.state))
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.http(SyncHTTPFailure(
                statusCode: http.statusCode,
                method: method,
                url: url.absoluteString,
                responseBody: text,
                requestBodyBytes: body?.count,
                context: context
            ))
        }
        return data
    }

    private func makeRequest(
        path: String,
        method: String,
        contentType: String? = nil
    ) -> URLRequest {
        var url = baseURL
        url.append(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let contentType {
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    public enum GalleryFetch: Sendable {
        case modified(GalleryResponse)
        case notModified
    }

    /// Conditional pull: pass the local `updatedAt` as `ifNoneMatch` to get `.notModified` (304) when
    /// the photo catalog is unchanged, transferring nothing.
    public func fetchGallery(ifNoneMatch: String? = nil) async throws -> GalleryFetch {
        var req = makeRequest(path: "/api/gallery", method: "GET")
        if let ifNoneMatch, !ifNoneMatch.isEmpty {
            req.setValue("\"\(ifNoneMatch)\"", forHTTPHeaderField: "If-None-Match")
        }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw SyncError.decode }
        if http.statusCode == 304 { return .notModified }
        guard (200...299).contains(http.statusCode) else {
            throw SyncError.http(SyncHTTPFailure(
                statusCode: http.statusCode,
                method: "GET",
                url: req.url?.absoluteString ?? baseURL.absoluteString,
                responseBody: String(data: data, encoding: .utf8) ?? "",
                context: "fetch gallery"
            ))
        }
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return .modified(decoded)
    }

    /// Cheap poll for the currently shown photo (catches cron rotations without a full catalog pull).
    public func fetchCurrentPhoto() async throws -> CurrentPhotoResponse {
        let data = try await request(path: "/api/gallery/current", method: "GET")
        guard let decoded = try? JSONDecoder().decode(CurrentPhotoResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func uploadPhoto(
        jpegData: Data,
        filename: String,
        uploadedBy: String,
        baseUpdatedAt: String
    ) async throws -> GalleryResponse {
        let boundary = "gattey-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"uploadedBy\"\r\n\r\n")
        append("\(uploadedBy)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"baseUpdatedAt\"\r\n\r\n")
        append("\(baseUpdatedAt)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n")
        append("\(filename)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n--\(boundary)--\r\n")
        let data = try await request(
            path: "/api/gallery/photos",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            context: "upload: \(filename) (JPEG \(body.count) bytes)"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func deletePhoto(id: PhotoID, baseUpdatedAt: String) async throws -> GalleryResponse {
        struct Body: Encodable { var baseUpdatedAt: String }
        let encoded = try JSONEncoder().encode(Body(baseUpdatedAt: baseUpdatedAt))
        let data = try await request(
            path: "/api/gallery/photos/\(id)",
            method: "DELETE",
            body: encoded,
            contentType: "application/json"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func reorder(_ order: [PhotoID], baseUpdatedAt: String) async throws -> GalleryResponse {
        struct Body: Encodable {
            var order: [PhotoID]
            var baseUpdatedAt: String
        }
        let encoded = try JSONEncoder().encode(Body(order: order, baseUpdatedAt: baseUpdatedAt))
        let data = try await request(
            path: "/api/gallery/order",
            method: "PUT",
            body: encoded,
            contentType: "application/json",
            context: "reorder \(order.count) photos"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func renameUploader(
        fromName: String,
        toName: String,
        baseUpdatedAt: String
    ) async throws -> GalleryResponse {
        struct Body: Encodable {
            var fromName: String
            var toName: String
            var baseUpdatedAt: String
        }
        let encoded = try JSONEncoder().encode(
            Body(fromName: fromName, toName: toName, baseUpdatedAt: baseUpdatedAt)
        )
        let data = try await request(
            path: "/api/gallery/uploaders",
            method: "PATCH",
            body: encoded,
            contentType: "application/json",
            context: "rename uploader \(fromName) → \(toName)"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func setCurrentPhoto(id: PhotoID, baseUpdatedAt: String) async throws -> GalleryResponse {
        struct Body: Encodable {
            var photoId: PhotoID
            var baseUpdatedAt: String
        }
        let encoded = try JSONEncoder().encode(Body(photoId: id, baseUpdatedAt: baseUpdatedAt))
        let data = try await request(
            path: "/api/gallery/current",
            method: "PUT",
            body: encoded,
            contentType: "application/json"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func imageURL(for photo: PhotoEntry, width: Int? = nil) -> URL {
        var url = baseURL.appending(path: "api/gallery/photos/\(photo.id)/image")
        if let width {
            url.append(queryItems: [URLQueryItem(name: "w", value: String(width))])
        }
        return url
    }

    public func listDevices() async throws -> [RegisteredDevicePublic] {
        let data = try await request(path: "/api/devices", method: "GET")
        guard let decoded = try? JSONDecoder().decode(DeviceListResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded.devices
    }

    public func registerDevice(setupText: String, displayName: String?, registeredBy: String) async throws -> RegisteredDevicePublic {
        struct Body: Encodable {
            var setupText: String
            var displayName: String?
            var registeredBy: String
        }
        let encoded = try JSONEncoder().encode(Body(setupText: setupText, displayName: displayName, registeredBy: registeredBy))
        let data = try await request(
            path: "/api/devices",
            method: "POST",
            body: encoded,
            contentType: "application/json"
        )
        guard let decoded = try? JSONDecoder().decode(DeviceRegisterResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded.device
    }

    public func deleteDevice(id: String) async throws {
        _ = try await request(path: "/api/devices/\(id)", method: "DELETE")
    }

    public func fetchDeviceStatus() async throws -> [DeviceLiveStatus] {
        let data = try await request(path: "/api/devices/status", method: "GET")
        guard let decoded = try? JSONDecoder().decode(DeviceStatusResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded.devices
    }

    public func cachePhotoIfMissing(_ photo: PhotoEntry) async throws {
        try await downloadImageIfMissing(
            photo,
            width: nil,
            to: AppConfig.cacheURL(for: photo.id)
        )
    }

    /// Downloads a width-bounded thumbnail variant for the grid (much smaller than the full image).
    public func cacheThumbnailIfMissing(_ photo: PhotoEntry, width: Int) async throws {
        try await downloadImageIfMissing(
            photo,
            width: width,
            to: AppConfig.thumbnailCacheURL(for: photo.id, width: width)
        )
    }

    private func downloadImageIfMissing(
        _ photo: PhotoEntry,
        width: Int?,
        to dest: URL
    ) async throws {
        if FileManager.default.fileExists(atPath: dest.path) { return }
        let reqURL = imageURL(for: photo, width: width)
        let authBearer = bearer
        let urlSession = session
        let photoID = photo.id
        let baseStr = baseURL.absoluteString
        try await ImageDownloadDeduplicator.shared.run(key: dest.path) {
            if FileManager.default.fileExists(atPath: dest.path) { return }
            var req = URLRequest(url: reqURL)
            req.setValue("Bearer \(authBearer)", forHTTPHeaderField: "Authorization")
            let (data, res) = try await urlSession.data(for: req)
            guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (res as? HTTPURLResponse)?.statusCode ?? -1
                throw SyncError.http(SyncHTTPFailure(
                    statusCode: code,
                    method: "GET",
                    url: req.url?.absoluteString ?? baseStr,
                    responseBody: "image download failed",
                    context: "cache photo \(photoID)\(width.map { " w=\($0)" } ?? "")"
                ))
            }
            try data.write(to: dest, options: .atomic)
        }
    }

    public func downloadMissing(for state: GalleryState, maxConcurrency: Int = 6) async throws {
        let missing = state.activePhotos().filter { photo in
            !FileManager.default.fileExists(atPath: AppConfig.cacheURL(for: photo.id).path)
        }
        guard !missing.isEmpty else { return }
        let limit = max(1, maxConcurrency)
        await withTaskGroup(of: (PhotoID, String?).self) { group in
            var iterator = missing.makeIterator()
            for _ in 0..<min(limit, missing.count) {
                guard let photo = iterator.next() else { break }
                group.addTask {
                    do {
                        try await self.cachePhotoIfMissing(photo)
                        return (photo.id, nil)
                    } catch {
                        return (photo.id, error.localizedDescription)
                    }
                }
            }
            for await (photoID, errorDescription) in group {
                if let errorDescription {
                    await MainActor.run {
                        ActivityLogStore.shared.log(
                            .gallery,
                            level: .warning,
                            "Could not cache photo from server",
                            detail: "\(photoID): \(errorDescription)"
                        )
                    }
                }
                if let next = iterator.next() {
                    group.addTask {
                        do {
                            try await self.cachePhotoIfMissing(next)
                            return (next.id, nil)
                        } catch {
                            return (next.id, error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
