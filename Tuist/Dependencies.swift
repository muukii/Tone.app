import ProjectDescription

let app = SwiftPackageManagerDependencies([
  .package(url: "https://github.com/AudioKit/AudioKit", .upToNextMajor(from: "5.6.2")),
  .package(url: "https://github.com/dagronf/SwiftSubtitles", .upToNextMajor(from: "0.5.0")),
  .package(url: "https://github.com/VergeGroup/Verge", .branch("main")),
  .package(url: "https://github.com/FluidGroup/swift-dynamic-list", .branch("main")),
  .package(url: "https://github.com/FluidGroup/swiftui-support", .branch("main")),
  .package(url: "https://github.com/VergeGroup/Wrap", .upToNextMajor(from: "4.0.0")),
])

let dependencies = Dependencies(
  carthage: [],
  swiftPackageManager: app,
  platforms: [.iOS]
)
