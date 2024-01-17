import ProjectDescription

let project = Project(
  name: "Tone",
  organizationName: "MuukLab",
  options: .options(
    developmentRegion: "en",
    disableBundleAccessors: true,
    disableSynthesizedResourceAccessors: true,
    textSettings: .textSettings(
      usesTabs: false,
      indentWidth: 2,
      tabWidth: 2,
      wrapsLines: true
    ),
    xcodeProjectName: "Tone"
  ),
  packages: [
//    .package(url: "https://github.com/exPHAT/SwiftWhisper", .branch("master")),
//    .package(url: "https://github.com/Priva28/SwiftWhisper", .branch("master")),
    .package(path: "./SwiftWhisper"),
//    .package(url: "https://github.com/muukii/SwiftWhisper", .branch("muukii/follow-upstream")),
    .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.5.5"),
  ],
  targets: [
    Target(
      name: "Tone",
      destinations: [.iPhone, .macWithiPadDesign],
      product: .app,
      bundleId: "app.muukii.tone",
      deploymentTargets: .iOS("17.0"),
      // infoPlist: "Supporting/Info.plist",
      infoPlist: .extendingDefault(with: [
        "CFBundleShortVersionString": "2.0.0",
        "UIBackgroundModes": ["audio"],
        "UIApplicationSceneManifest": [
          "UIApplicationSupportsMultipleScenes": "YES",
          "UISceneConfigurations": [:],
        ],
        "UILaunchScreen": ["UILaunchScreen": [:]],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "NSMicrophoneUsageDescription":
          "To record your voice and play it back for pronunciation practice.",
      ]),
      sources: ["ShadowingPlayer/**"],
      resources: [
        "ShadowingPlayer/Assets.xcassets",
        "ShadowingPlayer/Preview Content/**",
      ],
      dependencies: [

        .package(product: "SwiftWhisper"),

        .external(name: "AudioKit"),
        .external(name: "Verge"),
        .external(name: "HexColorMacro"),
        .package(product: "ZipArchive"),
        .target(name: "AppService"),

        .external(name: "DSWaveformImageViews"),
        .external(name: "SwiftSubtitles"),
        .external(name: "DynamicList"),
        .external(name: "SwiftUISupport"),
        .external(name: "Wrap"),
        .external(name: "MondrianLayout"),
        .external(name: "SwiftUIIntrospect"),

        .external(name: "SwiftUIRingSlider"),
      ],
      settings: .settings(base: [
        "DEVELOPMENT_ASSET_PATHS": #""ShadowingPlayer/Preview Content""#,
        "TARGETED_DEVICE_FAMILY": "1",
        "DEVELOPMENT_TEAM": "KU2QEJ9K3Z",
      ])
      // mergedBinaryType: .manual(mergeableDependencies: ["AppService"]),
      // mergeable: false
    ),

    Target(
      name: "AppService",
      destinations: [.iPhone],
      product: .staticFramework,
      bundleId: "app.muukii.Speaking.AppService",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/AppService/**"],
      dependencies: [
        .external(name: "Verge"),
        .external(name: "Wrap"),
      ]
      // mergedBinaryType: .disabled,
      // mergeable: true
    ),
  ],
  schemes: [
    .init(
      name: "Tone",
      shared: true,
      hidden: false,
      buildAction: .init(targets: ["Tone"]),
      testAction: nil,
      runAction: .runAction(configuration: "Debug", attachDebugger: true),
      archiveAction: .archiveAction(configuration: "Release"),
      profileAction: .profileAction(configuration: "Debug"),
      analyzeAction: nil
    )
  ]
)
