// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "pdfmaker",
    targets: [
        .executableTarget(
            name: "pdfmaker",
            path: "pdfmaker",
            exclude: [
                // File not needed for Linux build (so far...)
                "Info.plist"
            ]
        )
    ]
)
