import Observation

@MainActor
@Observable
public final class AppChromeState {
    public var showActivityInspector = false
    /// Leading device preview column in the gallery split (session chrome; not persisted).
    public var showDevicePreview = true

    public init() {}

    /// Trailing inspector toggle (toolbar + View menu). Same symbol for show and hide.
    public static let activityInspectorSymbolName = "sidebar.trailing"

    /// Leading preview toggle (`Toggle` + `.toggleStyle(.button)` in toolbar).
    public static let devicePreviewToggleSymbolName = "sidebar.left"
}
