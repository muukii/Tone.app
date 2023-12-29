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
  targets: [
    Target(
      name: "Tone",
      destinations: [.iPhone, .macWithiPadDesign],
      product: .app,
      bundleId: "app.muukii.tone",
      deploymentTargets: .iOS("17.0"),
      // infoPlist: "Supporting/Info.plist",
      infoPlist: .extendingDefault(with: [
        "UIBackgroundModes" : ["audio"],
        "UIApplicationSceneManifest" : [
          "UIApplicationSupportsMultipleScenes" : "YES",
          "UISceneConfigurations" : [:]
        ],
        "UILaunchScreen" : ["UILaunchScreen": [:]],
        "UISupportedInterfaceOrientations" : ["UIInterfaceOrientationPortrait"],
        "NSMicrophoneUsageDescription" : "For recording audio from microphone"
        ]),
      sources: ["ShadowingPlayer/**"],
      resources: [
        "ShadowingPlayer/Assets.xcassets",
        "ShadowingPlayer/Preview Content/**",
      ],
      dependencies: [
        .external(name: "AudioKit"),
        .external(name: "SwiftSubtitles"),
        .external(name: "Verge"),
        .external(name: "DynamicList"),
        .external(name: "SwiftUISupport"),
        .target(name: "AppService"),
        .external(name: "Wrap"),
        .external(name: "MondrianLayout"),
        .external(name: "SwiftUIIntrospect"),
        .external(name: "HexColorMacro"),
      ],
      settings: .settings(base: [
        "DEVELOPMENT_ASSET_PATHS": #""ShadowingPlayer/Preview Content""#,
        "TARGETED_DEVICE_FAMILY": "1",
        "DEVELOPMENT_TEAM" : "KU2QEJ9K3Z"
      ])
      // mergedBinaryType: .manual(mergeableDependencies: ["AppService"]),
      // mergeable: false
    ),

    Target(
      name: "AppService",
      destinations: [.iPhone],
      product: .framework,
      bundleId: "app.muukii.Speaking.AppService",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/AppService/**"],
      dependencies: [
        .external(name: "Verge"),
        .external(name: "Wrap"),
      ]
      // mergedBinaryType: .disabled,
      // mergeable: true
    )
  ]
)
