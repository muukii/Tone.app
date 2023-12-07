import ProjectDescription

let project = Project(
  name: "Speaking",
  organizationName: "MuukLab",
  options: .options(
    developmentRegion: "ja",
    disableBundleAccessors: true,
    disableSynthesizedResourceAccessors: true,
    textSettings: .textSettings(
      usesTabs: false,
      indentWidth: 2,
      tabWidth: 2, 
      wrapsLines: true
    ),
    xcodeProjectName: "Speaking"
  ),
  targets: [
      Target(
        name: "Speaking",
        platform: .iOS,
        product: .app,
        bundleId: "app.muukii.Speaking",
        // infoPlist: "Supporting/Info.plist",
        infoPlist: .extendingDefault(with: [
          "UIApplicationSceneManifest" : [
            "UIApplicationSupportsMultipleScenes" : "YES",            
            "UISceneConfigurations" : [:]
          ],
          "UILaunchScreen" : ["UILaunchScreen": [:]],
          "UISupportedInterfaceOrientations" : ["UIInterfaceOrientationPortrait"]
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
        ],
        settings: .settings(base: [
          "DEVELOPMENT_ASSET_PATHS": #""ShadowingPlayer/Preview Content""#,
          "TARGETED_DEVICE_FAMILY": "1"
        ])
      ),        
    ]
)