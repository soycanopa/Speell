// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Speell",
    // 13.4 por `UnevenRoundedRectangle` —la forma de la tab activa y del pane
    // redondea esquinas distintas—; antes de eso no existe en SwiftUI.
    platforms: [.macOS("13.4")],
    targets: [
        // libghostty del pin (Vendor/ghostty.pin). Lo genera
        // Scripts/build-libghostty.sh; no se commitea por peso.
        .binaryTarget(name: "GhosttyKit", path: "Vendor/GhosttyKit.xcframework"),

        .executableTarget(
            name: "Speell",
            dependencies: ["GhosttyKit"],
            path: "Sources/Speell",
            resources: [.copy("Resources/")],
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

        .testTarget(
            name: "SpeellTests",
            dependencies: ["Speell"],
            path: "Tests/SpeellTests"
        ),
    ]
)
