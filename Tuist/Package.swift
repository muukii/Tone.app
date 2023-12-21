// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Tuist",
  dependencies: [
    .package(path: "../../../submodules/FluidGroup/swift-dynamic-list"),
    .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.2"),
    .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "0.5.0"),
    .package(url: "https://github.com/VergeGroup/Verge", branch: "main"),
    .package(url: "https://github.com/FluidGroup/swiftui-support", branch: "main"),
    .package(url: "https://github.com/VergeGroup/Wrap", from: "4.0.0"),
  ]
)