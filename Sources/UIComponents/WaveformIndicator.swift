import SwiftUI

public struct WaveformIndicator: View {
  
  public let isPlaying: Bool
  
  public init(isPlaying: Bool) {
    self.isPlaying = isPlaying
  }
  
  public var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4) { index in
        RoundedRectangle(cornerRadius: 2)
          .fill(.tint)
          .frame(
            width: 3,
            height: isPlaying ? CGFloat.random(in: 8...24) : 16
          )
          .animation(
            isPlaying ? 
              .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1) :
              .default,
            value: isPlaying
          )
      }
    }
    .frame(width: 24, height: 24)
  }
}

#Preview("WaveformIndicator") {
  VStack(spacing: 40) {
    VStack(spacing: 16) {
      Text("Playing")
        .font(.headline)
      
      WaveformIndicator(isPlaying: true)
        .foregroundColor(.blue)
    }
    
    VStack(spacing: 16) {
      Text("Paused")
        .font(.headline)
      
      WaveformIndicator(isPlaying: false)
        .foregroundColor(.blue)
    }
    
    VStack(spacing: 16) {
      Text("Different Colors")
        .font(.headline)
      
      HStack(spacing: 20) {
        WaveformIndicator(isPlaying: true)
          .foregroundColor(.green)
        
        WaveformIndicator(isPlaying: true)
          .foregroundColor(.orange)
        
        WaveformIndicator(isPlaying: true)
          .foregroundColor(.purple)
      }
    }
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color(.systemGray6))
}
