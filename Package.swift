// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CueFetch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CueFetch", targets: ["CueFetch"])
    ],
    targets: [
        .target(
            name: "CueFetchCore",
            path: "Sources/CueFetchCore"
        ),
        .executableTarget(
            name: "CueFetch",
            dependencies: ["CueFetchCore"],
            path: "Sources/CueFetch",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "CueFetchCoreTests",
            dependencies: ["CueFetchCore"],
            path: "Tests/CueFetchCoreTests"
        )
    ]
)
