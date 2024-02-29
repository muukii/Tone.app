// swift-tools-version:5.9
import PackageDescription

var exclude: [String] = []

#if os(Linux)
// Linux doesn't support CoreML, and will attempt to import the coreml source directory
exclude.append("coreml")
#endif

let package = Package(
    name: "SwiftWhisper",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "SwiftWhisper", targets: ["SwiftWhisper"])
    ],
    dependencies: [
      .package(url: "https://github.com/ggerganov/whisper.cpp", branch: "master")
    ],
    targets: [
        .target(
            name: "SwiftWhisper",
            dependencies: [.product(name: "whisper", package: "whisper.cpp")]
        ),
        .testTarget(
            name: "WhisperTests",
            dependencies: ["SwiftWhisper"],
            resources: [.copy("TestResources/")]
        )
    ],
    cxxLanguageStandard: CXXLanguageStandard.cxx11
)

