import SwiftUI

private struct _Book<MainContent: View, ControlContent: View>: View {
  
  let mainContent: MainContent
  let controlContent: ControlContent
  @State private var controlHeight: CGFloat = 0
  
  init(
    @ViewBuilder mainContent: () -> MainContent,
    @ViewBuilder controlContent: () -> ControlContent
  ) {
    self.mainContent = mainContent()
    self.controlContent = controlContent()
  }
  
  var body: some View {
    ZStack {      
      Rectangle()
        .fill(.background)
        .environment(\.colorScheme, .dark)
        
      ZStack {
        
        Color.red
          .ignoresSafeArea()
        
        mainContent
        
      }
      .frame(maxHeight: .infinity)
      .mask(        
        RoundedRectangle(
          cornerRadius: 30
        )   
        .ignoresSafeArea(edges: .top)
      )
      .transaction { transaction in 
        print("Content Transaction: \(transaction)")
      }
    }    
    .onGeometryChange(
      for: CGFloat.self,
      of: \.size.height,
      action: { old, new in
        self.controlHeight = new
      })
    .safeAreaInset(
      edge: .bottom,
      spacing: 0
    ) { 
      controlContent
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.background)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.colorScheme, .dark)
    }
    .transaction { transaction in 
      print("Transaction: \(transaction)")
    }
//    .animation(.smooth, value: controlHeight)
  }
}

#Preview("Platter") {
  struct PreviewWrapper: View {
    @State private var showMoreControls = false
    @State private var volumeExpanded = false
    @State private var showLyrics = false
    
    var body: some View {
      _Book(
        mainContent: {
          VStack(spacing: 20) {
            Text("メインコンテンツ")
              .font(.largeTitle)
              .foregroundColor(.white)
            
            Text("コントロールエリアの高さ: \(showMoreControls ? "拡張" : "通常")")
              .foregroundColor(.white.opacity(0.8))
          }
        },
        controlContent: {
          VStack(spacing: 16) {
            // メインコントロール
            HStack(spacing: 20) {
              Button(action: {}) {
                Image(systemName: "backward.fill")
                  .font(.title2)
              }
              
              Button(action: {}) {
                Image(systemName: "play.fill")
                  .font(.title)
              }
              
              Button(action: {}) {
                Image(systemName: "forward.fill")
                  .font(.title2)
              }
            }
            
            // 拡張ボタン
            Button(action: {
              showMoreControls.toggle()
            }) {
              HStack {
                Text(showMoreControls ? "コントロールを閉じる" : "もっと見る")
                Image(systemName: showMoreControls ? "chevron.down" : "chevron.up")
              }
              .font(.caption)
            }
            
            // 拡張コンテンツ
            if showMoreControls {
              VStack(spacing: 12) {
                // ボリュームコントロール
                Button(action: {
                  volumeExpanded.toggle()
                }) {
                  HStack {
                    Image(systemName: "speaker.wave.2")
                    Text("ボリューム")
                    Spacer()
                    Image(systemName: volumeExpanded ? "chevron.up" : "chevron.down")
                  }
                  .padding(.horizontal)
                }
                
                if volumeExpanded {
                  Slider(value: .constant(0.5))
                    .padding(.horizontal)
                }
                
                // 歌詞表示トグル
                Toggle(isOn: $showLyrics) {
                  HStack {
                    Image(systemName: "text.bubble")
                    Text("歌詞を表示")
                  }
                }
                .padding(.horizontal)
                
                if showLyrics {
                  Text("♪ ここに歌詞が表示されます...")
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // その他のオプション
                HStack(spacing: 16) {
                  Button(action: {}) {
                    VStack {
                      Image(systemName: "repeat")
                      Text("リピート")
                        .font(.caption2)
                    }
                  }
                  
                  Button(action: {}) {
                    VStack {
                      Image(systemName: "shuffle")
                      Text("シャッフル")
                        .font(.caption2)
                    }
                  }
                  
                  Button(action: {}) {
                    VStack {
                      Image(systemName: "airplayaudio")
                      Text("AirPlay")
                        .font(.caption2)
                    }
                  }
                }
                .padding(.top, 8)
              }
            }
          }
          .padding(.horizontal)
        }
      )
    }
  }
  
  return PreviewWrapper()
}
