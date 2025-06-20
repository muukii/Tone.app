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
  packages: [],
  settings: .settings(
    base: [
      "CURRENT_PROJECT_VERSION": "1",
      "MARKETING_VERSION": "$(APP_SHORT_VERSION)",
      "SWIFT_VERSION": "6.0",
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
      deploymentTargets: .iOS("18.0"),
      // infoPlist: "Supporting/Info.plist",
      infoPlist: .extendingDefault(with: [
        "CFBundleShortVersionString": "$(APP_SHORT_VERSION)",
        "UIBackgroundModes": ["audio", "processing"],
        "UIApplicationSceneManifest": [
          "UIApplicationSupportsMultipleScenes": "YES",
          "UISceneConfigurations": [:],
        ],
        "NSSupportsLiveActivities": "YES",
        "UILaunchScreen": ["UILaunchScreen": [:]],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "NSMicrophoneUsageDescription":
          "To record your voice and play it back for pronunciation practice.",
      ]),
      sources: ["ShadowingPlayer/**"],
      resources: [
        "ShadowingPlayer/Assets.xcassets",
        "ShadowingPlayer/Preview Content/**",
        "ShadowingPlayer/PrivacyInfo.xcprivacy",
      ],
      entitlements: .dictionary([
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.developer.icloud-container-identifiers": ["iCloud.app.muukii.tone"],
        "com.apple.security.application-groups": ["group.app.muukii.tone"],
        "com.apple.developer.background-tasks.continued-processing.gpu": true,
      ]),
      dependencies: [
        .sdk(name: "CloudKit", type: .framework),
        
        .external(name: "YouTubeKit"),
        .external(name: "AudioKit"),
        .external(name: "StateGraph"),
        .external(name: "HexColorMacro"),
        .external(name: "SwiftUIPersistentControl"),
        .external(name: "FunctionalViewComponent"),
        .external(name: "SteppedSlider"),
        .external(name: "ObjectEdge"),
        .external(name: "Alamofire"),
        .external(name: "SwiftUIStack"),

        .target(name: "AppService"),
        .target(name: "ActivityContent"),
        .target(name: "LiveActivity"),
        .target(name: "UIComponents"),
        
        .external(name: "ConcurrencyTaskManager"),

        .external(name: "DSWaveformImageViews"),
        .external(name: "SwiftSubtitles"),
        .external(name: "DynamicList"),
        .external(name: "CollectionView"),
        .external(name: "SwiftUISupportLayout"),
        .external(name: "SwiftUISupport"),
        .external(name: "Wrap"),
        .external(name: "MondrianLayout"),
        .external(name: "SwiftUIIntrospect"),
        .external(name: "Algorithms"),

        .external(name: "SwiftUIRingSlider"),
      ],
      settings: .settings(base: [
        "DEVELOPMENT_ASSET_PATHS": #""ShadowingPlayer/Preview Content""#,
        "TARGETED_DEVICE_FAMILY": "1",
        "DEVELOPMENT_TEAM": "KU2QEJ9K3Z",
        "OTHER_LDFLAGS": "$(inherited) -all_load",
      ])
    ),

    .target(
      name: "LiveActivity",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "app.muukii.tone.LiveActivity",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .dictionary([
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleDisplayName": "Tone Widget",
        "CFBundleShortVersionString": "$(APP_SHORT_VERSION)",
        "CFBundleIdentifier": "$PRODUCT_BUNDLE_IDENTIFIER",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ],
      ]),
      sources: ["Sources/LiveActivity/**"],
      entitlements: .dictionary([
        "com.apple.security.application-groups": ["group.app.muukii.tone"],
      ]),
      dependencies: [
        .target(name: "ActivityContent")
      ],
      settings: .settings(base: [
        "DEVELOPMENT_TEAM": "KU2QEJ9K3Z"
      ])
    ),

    .target(
      name: "AppService",
      destinations: [.iPhone],
      product: .staticLibrary,
      bundleId: "app.muukii.Speaking.AppService",
      deploymentTargets: .iOS("18.0"),
      sources: ["Sources/AppService/**"],
      dependencies: [
        .target(name: "ActivityContent"),
        .external(name: "StateGraph"),
        .external(name: "WhisperKit"),
        .external(name: "Wrap"),
        .external(name: "SwiftSubtitles"),
        .external(name: "Alamofire"),
        .external(name: "UserDefaultsSnapshotLib"),
        .external(name: "ConcurrencyTaskManager"),
      ]
    ),

    .target(
      name: "ActivityContent",
      destinations: [.iPhone],
      product: .framework,
      bundleId: "app.muukii.Speaking.ActivityContent",
      deploymentTargets: .iOS("18.0"),
      sources: ["Sources/ActivityContent/**"],
      dependencies: []
    ),

    .target(
      name: "UIComponents",
      destinations: [.iPhone, .macWithiPadDesign],
      product: .framework,
      bundleId: "app.muukii.tone.UIComponents",
      deploymentTargets: .iOS("18.0"),
      sources: ["Sources/UIComponents/**"],
      dependencies: [
        .external(name: "SwiftUISupport"),
        .external(name: "SwiftUISupportLayout"),
        .external(name: "SteppedSlider"),
      ]
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
