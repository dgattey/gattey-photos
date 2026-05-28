// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GatteyPhotos",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GatteyPhotosCore", targets: ["GatteyPhotosCore"]),
        .executable(name: "GatteyPhotos", targets: ["GatteyPhotosApp"]),
        .executable(name: "GatteyPhotosSyncHelper", targets: ["GatteyPhotosSyncHelper"]),
    ],
    targets: [
        .target(
            name: "GatteyPhotosCore",
            path: "Sources/GatteyPhotosCore"
        ),
        .executableTarget(
            name: "GatteyPhotosApp",
            dependencies: ["GatteyPhotosCore"],
            path: "Sources/GatteyPhotosApp",
            swiftSettings: [.unsafeFlags(["-parse-as-library"], .when(configuration: .debug))]
        ),
        .executableTarget(
            name: "GatteyPhotosSyncHelper",
            dependencies: ["GatteyPhotosCore"],
            path: "Sources/GatteyPhotosSyncHelper"
        ),
    ]
)
