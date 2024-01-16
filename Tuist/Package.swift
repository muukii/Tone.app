// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Tuist",
  dependencies: [
    .package(path: "../../../submodules/FluidGroup/swift-dynamic-list"),
    .package(path: "../../../submodules/FluidGroup/swiftui-ring-slider"),
    .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "0.5.0"),
    .package(url: "https://github.com/VergeGroup/Verge", branch: "main"),
    .package(url: "https://github.com/FluidGroup/swiftui-support", branch: "main"),
    .package(url: "https://github.com/VergeGroup/Wrap", from: "4.0.0"),
    .package(url: "https://github.com/FluidGroup/MondrianLayout", branch: "main"),
    .package(url: "https://github.com/siteline/swiftui-introspect", from: "1.1.0"),
    .package(url: "https://github.com/muukii/swift-macro-hex-color", from: "0.1.1"),
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage", from: "14.2.2"),
//    .package(url: "https://github.com/ggerganov/whisper.cpp", branch: "master"),
  ]
)
