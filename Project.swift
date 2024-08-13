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
  ],
  settings: .settings(
    base: [
      "CURRENT_PROJECT_VERSION": "1",
      "MARKETING_VERSION": "$(APP_SHORT_VERSION)",
      "SWIFT_VERSION" : "6.0"
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
        "NSSupportsLiveActivities" : "YES",
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
      entitlements: .dictionary([:]),
      dependencies: [
        .external(name: "YouTubeKit"),
        .external(name: "AudioKit"),
        .external(name: "Verge"),
        .external(name: "HexColorMacro"),
        .target(name: "AppService"),
        .target(name: "ActivityContent"),
        .target(name: "LiveActivity"),

        .external(name: "DSWaveformImageViews"),
        .external(name: "SwiftSubtitles"),
        .external(name: "DynamicList"),
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
        dependencies: [
          .target(name: "ActivityContent"),
        ]
      ),

    .target(
      name: "AppService",
      destinations: [.iPhone],
      product: .staticLibrary,
      bundleId: "app.muukii.Speaking.AppService",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/AppService/**"],
      dependencies: [
        .target(name: "ActivityContent"),
        .external(name: "WhisperKit"),
        .external(name: "Verge"),
        .external(name: "Wrap"),
        .external(name: "SwiftSubtitles"),
      ]
    ),

    .target(
      name: "ActivityContent",
      destinations: [.iPhone],
      product: .framework,
      bundleId: "app.muukii.Speaking.ActivityContent",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/ActivityContent/**"],
      dependencies: [
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
