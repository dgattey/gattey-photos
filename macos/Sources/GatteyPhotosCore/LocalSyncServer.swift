import Foundation

public enum LocalSyncServerError: Error, LocalizedError {
    case notLocalURL
    case repoRootUnknown
    case scriptFailed(String)
    case unavailableOnPlatform

    public var errorDescription: String? {
        switch self {
        case .notLocalURL: return "Server control is only available for http://127.0.0.1:3000"
        case .repoRootUnknown:
            return "Repo path unknown. Run ./scripts/dev.sh once or set GATTEY_PHOTOS_ROOT."
        case .scriptFailed(let detail): return detail
        case .unavailableOnPlatform: return "Local sync server control is only available on macOS."
        }
    }
}

public enum LocalSyncServer {
    public static let defaultBaseURL = SyncServerURLs.localDevBaseURL

    public static func isLocalURL(_ baseURL: String) -> Bool {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased()
        else { return false }
        let localHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]
        guard localHosts.contains(host) else { return false }
        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        return port == 3000
    }

    #if os(macOS)
    public static func repoRoot() -> URL? {
        let rootFile = AppConfig.supportFolder.appendingPathComponent("repo-root.txt")
        if let text = try? String(contentsOf: rootFile, encoding: .utf8) {
            let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return URL(fileURLWithPath: path) }
        }
        if let env = ProcessInfo.processInfo.environment["GATTEY_PHOTOS_ROOT"] {
            let path = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    public static func saveRepoRoot(_ root: URL) {
        let path = root.path + "\n"
        try? path.write(toFile: AppConfig.supportFolder.appendingPathComponent("repo-root.txt").path, atomically: true, encoding: .utf8)
    }

    public static func pidFileURL() -> URL? {
        repoRoot()?.appendingPathComponent(".dev-server-supervisor.pid")
    }

    public static func isSupervisorRunning() -> Bool {
        guard let pidURL = pidFileURL(),
              let text = try? String(contentsOf: pidURL, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              pid > 0
        else { return false }
        return kill(pid, 0) == 0
    }

    public static func start() async throws {
        guard let root = repoRoot() else { throw LocalSyncServerError.repoRootUnknown }
        let script = root.appendingPathComponent("scripts/start-server.sh")
        let output = try await runScript(script)
        if output.contains("did not become ready") {
            throw LocalSyncServerError.scriptFailed(output)
        }
    }

    public static func stop() async throws {
        guard let root = repoRoot() else { throw LocalSyncServerError.repoRootUnknown }
        let script = root.appendingPathComponent("scripts/stop-server.sh")
        _ = try await runScript(script)
    }

    private static func runScript(_ script: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw LocalSyncServerError.scriptFailed("Missing script: \(script.path)")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [script.path]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            proc.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: LocalSyncServerError.scriptFailed(text.isEmpty ? "Exit \(process.terminationStatus)" : text))
                }
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #else
    public static func repoRoot() -> URL? { nil }

    public static func saveRepoRoot(_ root: URL) {}

    public static func pidFileURL() -> URL? { nil }

    public static func isSupervisorRunning() -> Bool { false }

    public static func start() async throws {
        throw LocalSyncServerError.unavailableOnPlatform
    }

    public static func stop() async throws {
        throw LocalSyncServerError.unavailableOnPlatform
    }
    #endif
}
