// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Haptyk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Haptyk",
            targets: ["Haptyk"]
        ),
        .library(
            name: "CHaptykAudio",
            targets: ["CHaptykAudio"]
        )
    ],
    targets: [
        .target(
            name: "CHaptykAudio",
            path: "Sources/CHaptykAudio",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AudioUnit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "Haptyk",
            dependencies: [
                "CHaptykAudio"
            ],
            path: "Sources/Haptyk",
            resources: [
                .copy("Resources/SoundPacks")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
