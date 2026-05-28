import Foundation

public enum SyncError: Error, LocalizedError {
    case badURL
    case http(Int, String)
    case decode
    case missingPassword

    public var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decode: return "Could not decode server response"
        case .missingPassword: return "Set sync password in Settings"
        }
    }
}

public struct SyncClient: Sendable {
    public var baseURL: URL
    public var password: String
    private let session: URLSession

    public init(settings: AppSettings, session: URLSession = .shared) throws {
        guard let url = URL(string: settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SyncError.badURL
        }
        guard !settings.syncPassword.isEmpty else {
            throw SyncError.missingPassword
        }
        self.baseURL = url
        self.password = settings.syncPassword
        self.session = session
    }

    private func request(path: String, method: String, body: Data? = nil, contentType: String? = nil) async throws -> Data {
        var url = baseURL
        url.append(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(password)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            if let contentType {
                req.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else {
            throw SyncError.http(-1, "no response")
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.http(http.statusCode, text)
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

    public func uploadPhoto(jpegData: Data, filename: String) async throws -> GalleryResponse {
        let boundary = "gattey-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
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
            contentType: "multipart/form-data; boundary=\(boundary)"
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

    public func downloadMissing(for state: GalleryState) async throws {
        for photo in state.activePhotos() {
            let dest = AppConfig.cacheURL(for: photo.id)
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            guard let urlString = photo.downloadUrl, let url = URL(string: urlString) else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(password)", forHTTPHeaderField: "Authorization")
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }
            try data.write(to: dest, options: .atomic)
        }
    }
}
