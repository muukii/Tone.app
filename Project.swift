import ProjectDescription

let version: Plist.Value = "4.0.0"

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
  settings: .settings(
    base: [
      "CURRENT_PROJECT_VERSION": "1",
      "MARKETING_VERSION": "$(APP_SHORT_VERSION)",
    ],
    configurations: [
      .debug(name: "Debug", settings: [:], xcconfig: "./xcconfigs/Project.xcconfig"),
      .release(name: "Release", settings: [:], xcconfig: "./xcconfigs/Project.xcconfig"),
    ]
  ),
  targets: [
    .target(
      name: "Tone",
      destinations: [.iPhone, .macWithiPadDesign],
      product: .app,
      bundleId: "app.muukii.tone",
      deploymentTargets: .iOS("17.0"),
      // infoPlist: "Supporting/Info.plist",
      infoPlist: .extendingDefault(with: [
        "CFBundleShortVersionString": "$(APP_SHORT_VERSION)",
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
      entitlements: .dictionary([:]),
      dependencies: [

        .package(product: "SwiftWhisper"),

        .external(name: "YouTubeKit"),
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
        "OTHER_LDFLAGS": "$(inherited) -all_load",
      ]),
      mergedBinaryType: .manual(mergeableDependencies: ["AppService"]),
      mergeable: false
    ),

    .target(
      name: "AppService",
      destinations: [.iPhone],
      product: .framework,
      bundleId: "app.muukii.Speaking.AppService",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/AppService/**"],
      dependencies: [
        .package(product: "SwiftWhisper"),
        .external(name: "Verge"),
        .external(name: "Wrap"),
      ],
      mergedBinaryType: .disabled,
      mergeable: true
    ),
  ],
  schemes: [
    .scheme(
      name: "Tone",
      shared: true,
      hidden: false,
      buildAction: .buildAction(targets: ["Tone"]),
      testAction: nil,
      runAction: .runAction(configuration: "Debug", attachDebugger: true),
      archiveAction: .archiveAction(configuration: "Release"),
      profileAction: .profileAction(configuration: "Debug"),
      analyzeAction: nil
    )
  ]
)
