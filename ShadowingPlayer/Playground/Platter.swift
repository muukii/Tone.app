import SwiftUI

struct Platter<MainContent: View, ControlContent: View>: View {

  let mainContent: MainContent
  let controlContent: ControlContent

  private let fixedHeight: CGFloat = 60
  private let isExpanded: Bool
  private let _onTapMainContent: () -> Void
  
  @State private var mainContentHeight: CGFloat?
  @State private var controlHeight: CGFloat?

  init(
    isExpanded: Bool = false,
    onTapMainContent: @escaping () -> Void = {},
    @ViewBuilder mainContent: () -> MainContent,
    @ViewBuilder controlContent: () -> ControlContent
  ) {
    self.isExpanded = isExpanded
    self._onTapMainContent = onTapMainContent
    self.mainContent = mainContent()
    self.controlContent = controlContent()
  }

  var body: some View {
    GeometryReader { proxy in 
      ZStack {
        
        Rectangle()
          .fill(.background)
          .environment(\.colorScheme, .dark)
        
        ZStack {
          
          Rectangle()
            .fill(.background)
            .ignoresSafeArea()
          
          mainContent
            .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets, action: { newValue in
              print(newValue)
            })
            .onGeometryChange(for: CGFloat.self, of: \.size.height, action: { oldValue, newValue in
              if isExpanded == false && newValue != oldValue {
                mainContentHeight = newValue
              }
            })
            .frame(
              width: nil,
              height: isExpanded ? proxy.size.height : nil
            )
            .allowsHitTesting(isExpanded == false)
            .overlay(
              Color.black.opacity(isExpanded ? 0.3 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(isExpanded)
                .gesture(
                  TapGesture().onEnded({
                    _onTapMainContent()
                  }), 
                  isEnabled: isExpanded
                )
            )
          
        }
        .frame(height: isExpanded ? fixedHeight : nil, alignment: .bottom)
        .mask(
          RoundedRectangle(
            cornerRadius: 30
          )
          .ignoresSafeArea(edges: .top)
        )
        .frame(maxHeight: .infinity, alignment: .top)
      }
      
      .safeAreaInset(
        edge: .bottom,
        spacing: 0
      ) {
        controlContent
          .onGeometryChange(for: CGFloat.self, of: \.size.height, action: { newValue in
            controlHeight = newValue
          })
          .padding(.top, 16)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity)
          .background(.background)
          .fixedSize(horizontal: false, vertical: isExpanded ? false : true)
          .environment(\.colorScheme, .dark)
          .zIndex(-1)
      }
//      .animation(.smooth(duration: 0.4), value: isExpanded)
      .animation(.smooth(duration: 0.4), value: UUID())
    }
  }

}

#Preview("Platter") {
  struct PreviewWrapper: View {

    @State private var showMoreControls = false
    @State private var volumeExpanded = false
    @State private var showLyrics = false

    var body: some View {
      Platter(
        isExpanded: showLyrics,
        onTapMainContent: {
          showLyrics = false
        },        
        mainContent: {
          ScrollView {
            LazyVStack {
              Section {

                ForEach(0..<10, id: \.self) { _ in

                  VStack(alignment: .leading) {
                    Text("Title")
                      .font(.headline)
                    Text("Title")
                      .font(.subheadline)

                    RoundedRectangle(cornerRadius: 1)
                      .frame(height: 1)
                      .foregroundStyle(.quinary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 24)
                }

              } header: {

                Text("Header")
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 24)
                  .padding(.vertical, 10)
              }
            }
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
                  RoundedRectangle(cornerRadius: 20)
                    .padding(12)
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

#Preview("Shift") {
  
  ZStack {
    RoundedRectangle(cornerRadius: 20)
      .frame(width: 50, height: 200)
  }
  .frame(width: 100, height: 100, alignment: .bottom)
  .background(.gray)
  
}
