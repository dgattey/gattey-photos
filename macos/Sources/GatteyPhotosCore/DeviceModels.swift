import Foundation

public struct RegisteredDevicePublic: Codable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var registeredBy: String
    public var registeredAt: String
    public var lastPushAt: String?
    public var lastPushError: String?
}

public struct DeviceListResponse: Codable, Sendable {
    public var devices: [RegisteredDevicePublic]
}

public struct DeviceRegisterResponse: Codable, Sendable {
    public var device: RegisteredDevicePublic
}

public struct DeviceLiveStatus: Codable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var reachable: Bool
    public var name: String?
    public var width: Int?
    public var height: Int?
    public var orientation: String?
    public var remoteImageOn: Bool?
    public var remoteImageInterval: String?
    public var lastPushAt: String?
    public var lastPushError: String?
}

public struct DeviceStatusResponse: Codable, Sendable {
    public var devices: [DeviceLiveStatus]
}
