// swift-tools-version: 6.0
import PackageDescription

let dylCore: Target.Dependency = .product(name: "DylCore", package: "dyl-kit")

let package = Package(
    name: "GatteyPhotos",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "GatteyPhotos", targets: ["GatteyPhotosApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/dgattey/dyl-kit", from: "0.3.4"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.3"),
    ],
    targets: [
        .target(name: "GatteyPhotosCore", dependencies: [dylCore]),
        .target(name: "GatteyPhotosUI", dependencies: ["GatteyPhotosCore"], resources: [.process("Resources")]),
        // release-kit's bundler adds the @executable_path/../Frameworks rpath for the embedded Sparkle.framework.
        .executableTarget(
            name: "GatteyPhotosApp",
            dependencies: [
                "GatteyPhotosCore",
                "GatteyPhotosUI",
                dylCore,
                .product(name: "DylUpdates", package: "dyl-kit"),
            ]
        ),
        .testTarget(name: "GatteyPhotosCoreTests", dependencies: ["GatteyPhotosCore", "GatteyPhotosUI"]),
        .testTarget(
            name: "GatteyPhotosUITests",
            dependencies: [
                "GatteyPhotosCore",
                "GatteyPhotosUI",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ]
        ),
    ]
)
