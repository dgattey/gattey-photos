import Foundation

public enum SyncError: Error, LocalizedError {
    case badURL(String)
    case http(SyncHTTPFailure)
    case decode
    case missingSyncAuth

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
        }
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
        var url = baseURL
        url.append(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            if let contentType {
                req.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
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

    public func fetchGallery() async throws -> GalleryResponse {
        let data = try await request(path: "/api/gallery", method: "GET")
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func uploadPhoto(jpegData: Data, filename: String, uploadedBy: String) async throws -> GalleryResponse {
        let boundary = "gattey-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"uploadedBy\"\r\n\r\n")
        append("\(uploadedBy)\r\n")
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

    public func deletePhoto(id: PhotoID) async throws -> GalleryResponse {
        let data = try await request(path: "/api/gallery/photos/\(id)", method: "DELETE")
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func reorder(_ order: [PhotoID]) async throws -> GalleryResponse {
        struct Body: Encodable { var order: [PhotoID] }
        let encoded = try JSONEncoder().encode(Body(order: order))
        let data = try await request(
            path: "/api/gallery/order",
            method: "PUT",
            body: encoded,
            contentType: "application/json"
        )
        guard let decoded = try? JSONDecoder().decode(GalleryResponse.self, from: data) else {
            throw SyncError.decode
        }
        return decoded
    }

    public func setCurrentPhoto(id: PhotoID) async throws -> GalleryResponse {
        struct Body: Encodable { var photoId: PhotoID }
        let encoded = try JSONEncoder().encode(Body(photoId: id))
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

    public func imageURL(for photo: PhotoEntry) -> URL {
        if let urlString = photo.downloadUrl, let url = URL(string: urlString) {
            return url
        }
        return baseURL.appending(path: "api/gallery/photos/\(photo.id)/image")
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

    public func downloadMissing(for state: GalleryState) async throws {
        for photo in state.activePhotos() {
            let dest = AppConfig.cacheURL(for: photo.id)
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            var req = URLRequest(url: imageURL(for: photo))
            req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }
            try data.write(to: dest, options: .atomic)
        }
    }
}
