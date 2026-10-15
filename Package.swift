// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "pdfmaker",
    dependencies: [
        .package(url: "https://github.com/smittytone/clicore", branch: "develop"),
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
                "Info.plist",
                "swift.plist"
            ],
            linkerSettings: [
                // Embed `swift.plist` into the __TEXT,__info_plist Mach-O section so the binary
                // can be signed and notarized. `.unsafeFlags` is fine here because `pdfmaker` is
                // a top-level executable, not a library dependency.
                // macOS only: Linux has no Mach-O format and no notarization requirement.
                .unsafeFlags(
                    ["-Xlinker", "-sectcreate",
                     "-Xlinker", "__TEXT",
                     "-Xlinker", "__info_plist",
                     "-Xlinker", "pdfmaker/swift.plist"],
                    .when(platforms: [.macOS])
                )
            ]
        )
    ],

)
