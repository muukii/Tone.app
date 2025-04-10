// swift-tools-version: 5.9
@preconcurrency import PackageDescription

let package = Package(
  name: "Tuist",
  dependencies: [
    .package(path: "../submodules/FluidGroup/swift-dynamic-list"),
    .package(path: "../submodules/FluidGroup/swiftui-ring-slider"),
    .package(path: "../submodules/FluidGroup/swiftui-persistent-control"),
    .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "0.5.0"),
    .package(url: "https://github.com/VergeGroup/Verge", branch: "main"),
    .package(url: "https://github.com/FluidGroup/swiftui-support", branch: "main"),
    .package(url: "https://github.com/FluidGroup/swiftui-functional-component-macro", from: "1.0.0"),
    .package(url: "https://github.com/VergeGroup/Wrap", from: "4.0.0"),
    .package(url: "https://github.com/FluidGroup/MondrianLayout", branch: "main"),
    .package(url: "https://github.com/siteline/swiftui-introspect", from: "1.1.0"),
    .package(url: "https://github.com/muukii/swift-macro-hex-color", from: "0.1.1"),
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage", from: "14.2.2"),
    .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.2"),
    .package(url: "https://github.com/alexeichhorn/YouTubeKit", from: "0.2.0"),
    .package(url: "https://github.com/argmaxinc/whisperkit", from: "0.2.1"),
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
    .package(url: "https://github.com/shima11/SteppedSlider.git", branch: "main"),
  ]
)
