import DylCore
import Foundation

extension URLSession {
    /// Gallery sync. Uploads send full-size photos, so resources get longer than DylCore's default.
    public static let sync = URLSession.bounded(requestTimeout: 12, resourceTimeout: 180)
}
