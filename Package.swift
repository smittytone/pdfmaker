// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "pdfmaker",
    dependencies: [
        .package(url: "https://github.com/smittytone/clicore", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "pdfmaker",
            dependencies: [
                .product(name: "Clicore", package: "clicore"),
            ],
            path: "pdfmaker",
            exclude: [
                // File not needed for Linux build (so far...)
                "Info.plist"
            ],
        )
    ],

)
