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
    dependencies: [
        // macOS auto-update (canonical for non-App-Store apps). Linked only into the macOS shell.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
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
            dependencies: [
                "GatteyPhotosCore",
                "GatteyPhotosUI",
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/GatteyPhotosApp",
            swiftSettings: [.unsafeFlags(["-parse-as-library"], .when(configuration: .debug))],
            linkerSettings: [
                // package-macos.sh embeds Sparkle.framework under Contents/Frameworks.
                .unsafeFlags(
                    ["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"],
                    .when(platforms: [.macOS])
                ),
            ]
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
