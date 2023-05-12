//
//  ShadowingPlayerApp.swift
//  ShadowingPlayer
//
//  Created by Muukii on 2023/05/10.
//

import SwiftUI
import AVFAudio

@main
struct ShadowingPlayerApp: App {

  init() {
    do {
      let instance = AVAudioSession.sharedInstance()
      try instance.setCategory(.playback)

    } catch {

    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
