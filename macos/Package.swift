// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GatteyPhotos",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "GatteyPhotosCore", targets: ["GatteyPhotosCore"]),
        .library(name: "GatteyPhotosUI", targets: ["GatteyPhotosUI"]),
        .executable(name: "GatteyPhotos", targets: ["GatteyPhotosApp"]),
        .executable(name: "GatteyPhotosIOS", targets: ["GatteyPhotosIOS"]),
    ],
    targets: [
        .target(
            name: "GatteyPhotosCore",
            path: "Sources/GatteyPhotosCore"
        ),
        .testTarget(
            name: "GatteyPhotosCoreTests",
            dependencies: ["GatteyPhotosCore"],
            path: "Tests/GatteyPhotosCoreTests"
        ),
        .target(
            name: "GatteyPhotosUI",
            dependencies: ["GatteyPhotosCore"],
            path: "Sources/GatteyPhotosUI",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "GatteyPhotosApp",
            dependencies: ["GatteyPhotosCore", "GatteyPhotosUI"],
            path: "Sources/GatteyPhotosApp",
            swiftSettings: [.unsafeFlags(["-parse-as-library"], .when(configuration: .debug))]
        ),
        .executableTarget(
            name: "GatteyPhotosIOS",
            dependencies: ["GatteyPhotosCore", "GatteyPhotosUI"],
            path: "Sources/GatteyPhotosIOS",
            exclude: ["Info.plist"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"], .when(configuration: .debug))]
        ),
    ]
)
