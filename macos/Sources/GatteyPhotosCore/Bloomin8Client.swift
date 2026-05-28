import Foundation

public enum Bloomin8Error: Error, LocalizedError {
    case badDeviceIP
    case uploadFailed(Int, String)

    public var errorDescription: String? {
        switch self {
        case .badDeviceIP: return "Set device IP in Settings"
        case .uploadFailed(let code, let msg): return "Bloomin8 upload \(code): \(msg)"
        }
    }
}

public struct Bloomin8Client: Sendable {
    public var deviceIP: String
    public var gallery: String
    private let session: URLSession

    public init(settings: AppSettings, session: URLSession = .shared) throws {
        let ip = settings.deviceIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ip.isEmpty else { throw Bloomin8Error.badDeviceIP }
        self.deviceIP = ip
        self.gallery = settings.galleryName
        self.session = session
    }

    public func upload(jpegData: Data, filename: String, showNow: Bool = false) async throws {
        guard let url = URL(string: "http://\(deviceIP)/upload?filename=\(filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filename)&gallery=\(gallery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gallery)&show_now=\(showNow ? 1 : 0)") else {
            throw Bloomin8Error.badDeviceIP
        }
        let boundary = "bloomin8-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (res as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            throw Bloomin8Error.uploadFailed(code, text)
        }
    }

    public func syncDevice(from state: GalleryState) async throws {
        for photo in state.activePhotos() {
            let file = AppConfig.cacheURL(for: photo.id)
            guard let data = try? Data(contentsOf: file) else { continue }
            try await upload(jpegData: data, filename: photo.filename, showNow: false)
        }
    }
}
