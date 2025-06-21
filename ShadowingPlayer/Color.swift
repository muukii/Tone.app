import SwiftUI

struct ColorTester: View {

  init() {
  }

  var body: some View {
    VStack(spacing: 20) {
      Text("Hierarchy")
        .font(.title)
        .padding()

      VStack(alignment: .leading, spacing: 10) {
        StyleView(title: "Primary")
          .foregroundStyle(.primary)                
        StyleView(title: "Secondary")
          .foregroundStyle(.secondary)
        StyleView(title: "Secondary")
          .foregroundStyle(.tertiary)
        StyleView(title: "Quinary")
          .foregroundStyle(.quinary)
      }
      .backgroundStyle(.secondary)
      .padding()
    }
  }
}

private struct StyleView: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(.headline)
      Spacer()
      RoundedRectangle(cornerRadius: 8)
        .frame(width: 100, height: 50)
        .padding()
        .background(in:
          RoundedRectangle(cornerRadius: 8)
        )
    }
  }
}

#Preview {
  HStack {    
    ColorTester()
      .foregroundStyle(.orange)
      .environment(\.colorScheme, .dark)
    ColorTester()
      .foregroundStyle(.orange)
      .environment(\.colorScheme, .light)
  }
}

#Preview {
  Image(systemName: "swift")
    .padding()
    .background(
      in:
        Circle()
    )
    .backgroundStyle(.orange.gradient)
    .foregroundStyle(.red)
}

#Preview("Adaptive Color") {
    VStack(spacing: 20) {
        Text("Adaptive Color Demo")
            .font(.title)
        
        HStack(spacing: 20) {
            VStack {
                Text("Light Mode")
                    .font(.headline)
                ColorTester()
                    .environment(\.colorScheme, .light)
            }
            
            VStack {
                Text("Dark Mode")
                    .font(.headline)
                ColorTester()
                    .environment(\.colorScheme, .dark)
            }
        }
        
        HStack(spacing: 20) {
            Circle()
                .fill(AdaptiveColor(light: .blue, dark: .orange))
                .frame(width: 100, height: 100)
                .overlay(
                    Text("Blue/Orange")
                        .foregroundStyle(.white)
                )
            
            Circle()
                .fill(AdaptiveColor(light: .green, dark: .purple))
                .frame(width: 100, height: 100)
                .overlay(
                    Text("Green/Purple")
                        .foregroundStyle(.white)
                )
        }
    }
    .padding()
}

struct AdaptiveColor: ShapeStyle {
  
  let light: Color
  let dark: Color
  
  func resolve(in environment: EnvironmentValues) -> Color {
    
    if environment.colorScheme == .dark {
      return dark
    } else {
      return light
    }
    
  }
  
}


