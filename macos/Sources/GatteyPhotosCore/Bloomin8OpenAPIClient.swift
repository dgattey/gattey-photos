import Foundation

/// Bloomin8 cloud Open API (einkshot). Images are shown on the device's **next scheduled wake**, not immediately.
/// See `GET /open-api/help` on the service base URL.
public enum Bloomin8OpenAPIError: Error, LocalizedError {
    case missingToken
    case badBaseURL
    case missingCache(PhotoID)
    case invalidCacheFormat(PhotoID)
    case unsupportedImageFile(String)
    case apiFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken: return "Paste your Bloomin8 token in Settings"
        case .badBaseURL: return "Invalid Bloomin8 Open API URL"
        case .missingCache(let id): return "Missing cached image for \(id) — sync or open the gallery first"
        case .invalidCacheFormat(let id):
            return "Cached file for \(id) is not a readable image — re-download from server or re-upload"
        case .unsupportedImageFile(let name):
            return "Could not convert \(name) to JPEG for upload"
        case .apiFailed(let msg): return msg
        }
    }
}

public struct Bloomin8OpenAPIClient: Sendable {
    public static let defaultBaseURL = "https://einkshot-349134901638.us-central1.run.app"

    public var baseURL: URL
    public var token: String
    private let session: URLSession

    public init(settings: AppSettings, session: URLSession = .shared) throws {
        let raw = settings.bloomin8OpenApiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = raw.isEmpty ? Self.defaultBaseURL : raw
        guard let url = URL(string: base) else { throw Bloomin8OpenAPIError.badBaseURL }
        let tok = settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else { throw Bloomin8OpenAPIError.missingToken }
        self.baseURL = url
        self.token = tok
        self.session = session
    }

    private struct PushResponse: Decodable {
        var success: Bool
        var remote_image_id: String?
        var estimated_push_time: String?
        var error: String?
        var message: String?
    }

    /// `POST /open-api/push` multipart upload. Queues for next device wake (PENDING until pull).
    public func pushImage(jpegData: Data) async throws -> (remoteImageId: String?, estimatedPushTime: String?) {
        var url = baseURL
        url.append(path: "open-api/push")
        let boundary = "bloomin8-open-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 120

        let (data, res) = try await session.data(for: req)
        let code = (res as? HTTPURLResponse)?.statusCode ?? -1
        let decoded = try? JSONDecoder().decode(PushResponse.self, from: data)
        if let decoded, decoded.success {
            return (decoded.remote_image_id, decoded.estimated_push_time)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        if let decoded {
            throw Bloomin8OpenAPIError.apiFailed(Self.formatAPIFailure(httpCode: code, decoded: decoded, raw: text))
        }
        throw Bloomin8OpenAPIError.apiFailed("Open API \(code): \(text)")
    }

    private static func formatAPIFailure(httpCode: Int, error: String?, message: String?, raw: String) -> String {
        let code = error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let msg = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let code, !code.isEmpty, code != msg { parts.append(code) }
        if let msg, !msg.isEmpty { parts.append(msg) }
        if parts.isEmpty, let code, !code.isEmpty { parts.append(code) }
        if parts.isEmpty {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Open API \(httpCode)" : "Open API \(httpCode): \(trimmed)"
        }
        return "Open API \(httpCode): \(parts.joined(separator: " — "))"
    }

    private static func formatAPIFailure(httpCode: Int, decoded: PushResponse, raw: String) -> String {
        formatAPIFailure(httpCode: httpCode, error: decoded.error, message: decoded.message, raw: raw)
    }

    private struct DeviceStatusResponse: Decodable {
        var success: Bool?
        var device: DevicePayload?
        var message: String?
        var error: String?

        struct DevicePayload: Decodable {
            var name: String?
            var width: Int?
            var height: Int?
            var orientation: String?
            var remote_image_on: Bool?
            var remote_image_interval: String?
        }
    }

    /// `GET /open-api/device/status` — screen size, remote push flag, wake interval.
    public func fetchDeviceStatus() async throws -> Bloomin8CloudDeviceStatus {
        var url = baseURL
        url.append(path: "open-api/device/status")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let (data, res) = try await session.data(for: req)
        let code = (res as? HTTPURLResponse)?.statusCode ?? -1
        let decoded = try? JSONDecoder().decode(DeviceStatusResponse.self, from: data)
        if let decoded, decoded.success == true, let device = decoded.device {
            return Bloomin8CloudDeviceStatus(
                name: device.name,
                width: device.width,
                height: device.height,
                orientation: device.orientation,
                remoteImageOn: device.remote_image_on,
                remoteImageInterval: device.remote_image_interval
            )
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        if let decoded, decoded.success != true {
            throw Bloomin8OpenAPIError.apiFailed(
                Self.formatAPIFailure(httpCode: code, error: decoded.error, message: decoded.message, raw: text)
            )
        }
        throw Bloomin8OpenAPIError.apiFailed("Open API \(code): \(text)")
    }

    /// Whether the cloud API accepts the configured token (device reachable via einkshot).
    public static func pingDevice(settings: AppSettings) async -> Bool {
        let tok = settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else { return false }
        do {
            let client = try Bloomin8OpenAPIClient(settings: settings)
            _ = try await client.fetchDeviceStatus()
            return true
        } catch {
            return false
        }
    }
}

public struct Bloomin8CloudDeviceStatus: Sendable, Equatable {
    public var name: String?
    public var width: Int?
    public var height: Int?
    /// `"P"` portrait or `"L"` landscape (Open API device status).
    public var orientation: String?
    public var remoteImageOn: Bool?
    public var remoteImageInterval: String?
}

/// How a photo reached the Bloomin8 frame (cloud Open API queue).
public enum Bloomin8PushOutcome: Sendable, Equatable {
    case queuedRemote(estimatedPushTime: String?, remoteImageId: String?)
}

public enum Bloomin8DevicePush: Sendable {
    /// Queues the current photo via einkshot Open API (`POST /open-api/push`); displays on next device wake.
    public static func pushCurrentPhoto(_ photo: PhotoEntry, settings: AppSettings) async throws -> Bloomin8PushOutcome {
        let data = try PhotoCacheJPEG.jpegDataForDevicePush(photoID: photo.id)
        let open = try Bloomin8OpenAPIClient(settings: settings)
        let status = try await open.fetchDeviceStatus()
        let prepared = Bloomin8PushImage.prepare(jpegData: data, status: status)
        let result = try await open.pushImage(jpegData: prepared)
        return .queuedRemote(estimatedPushTime: result.estimatedPushTime, remoteImageId: result.remoteImageId)
    }
}
