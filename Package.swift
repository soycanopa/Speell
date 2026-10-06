// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Speell",
    platforms: [.macOS(.v13)],
    targets: [
        // libghostty del pin (Vendor/ghostty.pin). Lo genera
        // Scripts/build-libghostty.sh; no se commitea por peso.
        .binaryTarget(name: "GhosttyKit", path: "Vendor/GhosttyKit.xcframework"),

        .executableTarget(
            name: "Speell",
            dependencies: ["GhosttyKit"],
            path: "Sources/Speell",
            // libghostty es un C API síncrono sobre el hilo principal.
            // Antes de pelear con el modelo de concurrencia estricto, el
            // spike corre en modo de lenguaje 5.
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                // glslang (dentro de libghostty) usa la stdlib de C++.
                .linkedLibrary("c++"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreServices"),
                .linkedFramework("IOKit"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
    ]
)
