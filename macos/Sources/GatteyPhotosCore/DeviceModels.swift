import Foundation

public struct RegisteredDevicePublic: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var displayName: String
    public var registeredBy: String
    public var registeredAt: String
    public var lastPushAt: String?
    public var lastPushError: String?

    public init(
        id: String,
        displayName: String,
        registeredBy: String,
        registeredAt: String,
        lastPushAt: String? = nil,
        lastPushError: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.registeredBy = registeredBy
        self.registeredAt = registeredAt
        self.lastPushAt = lastPushAt
        self.lastPushError = lastPushError
    }
}

public struct DeviceListResponse: Codable, Sendable {
    public var devices: [RegisteredDevicePublic]
}

public struct DeviceRegisterResponse: Codable, Sendable {
    public var device: RegisteredDevicePublic
}

public struct DeviceLiveStatus: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var displayName: String
    public var registeredBy: String?
    public var reachable: Bool
    public var name: String?
    public var width: Int?
    public var height: Int?
    public var orientation: String?
    public var remoteImageOn: Bool?
    public var remoteImageInterval: String?
    public var lastPushAt: String?
    public var lastPushError: String?

    public init(
        id: String,
        displayName: String,
        registeredBy: String? = nil,
        reachable: Bool,
        name: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        orientation: String? = nil,
        remoteImageOn: Bool? = nil,
        remoteImageInterval: String? = nil,
        lastPushAt: String? = nil,
        lastPushError: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.registeredBy = registeredBy
        self.reachable = reachable
        self.name = name
        self.width = width
        self.height = height
        self.orientation = orientation
        self.remoteImageOn = remoteImageOn
        self.remoteImageInterval = remoteImageInterval
        self.lastPushAt = lastPushAt
        self.lastPushError = lastPushError
    }
}

public struct DeviceStatusResponse: Codable, Sendable {
    public var devices: [DeviceLiveStatus]
}

public enum DeviceOwnerFilter {
    public static func matches(registeredBy: String?, owner: String?) -> Bool {
        let trimmedOwner = (owner ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty else { return true }
        let trimmedRegistrant = (registeredBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedRegistrant.caseInsensitiveCompare(trimmedOwner) == .orderedSame
    }

    public static func filterDevices(
        _ devices: [RegisteredDevicePublic],
        owner: String?
    ) -> [RegisteredDevicePublic] {
        let trimmedOwner = (owner ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty else { return devices }
        return devices.filter { matches(registeredBy: $0.registeredBy, owner: trimmedOwner) }
    }

    public static func filterStatuses(
        _ statuses: [DeviceLiveStatus],
        owner: String?,
        knownDevices: [RegisteredDevicePublic] = []
    ) -> [DeviceLiveStatus] {
        let trimmedOwner = (owner ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOwner.isEmpty else { return statuses }
        let ownerByDeviceID = Dictionary(
            uniqueKeysWithValues: knownDevices.map { ($0.id, $0.registeredBy) }
        )
        return statuses.filter { status in
            let registeredBy = status.registeredBy ?? ownerByDeviceID[status.id]
            return matches(registeredBy: registeredBy, owner: trimmedOwner)
        }
    }
}
