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
        "UIBackgroundModes" : ["App plays audio or streams audio/video using AirPlay"],
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
        .target(name: "AppService"),    
        .external(name: "Wrap"),    
      ],
      settings: .settings(base: [
        "DEVELOPMENT_ASSET_PATHS": #""ShadowingPlayer/Preview Content""#,
        "TARGETED_DEVICE_FAMILY": "1"
      ])
      // mergedBinaryType: .manual(mergeableDependencies: ["AppService"]),
      // mergeable: false
    ),

    Target(
      name: "AppService",
      platform: .iOS,
      product: .framework,      
      bundleId: "app.muukii.Speaking.AppService",
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
