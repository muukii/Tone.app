import SwiftUI
import AppService

struct SettingsView: View {
  
  @StateObject var manager = ActivityManager.shared
  @AppStorage("openAIAPIKey") var openAIAPIKey: String = ""
  @AppStorage("selectedWhisperModel") var selectedWhisperModel: String = "small.en"
  
  @State private var availableModels: [String] = []
  @State private var downloadedModels: [String] = []
  @State private var downloadProgress: [String: Double] = [:]
  @State private var isLoading = false
  @State private var isLoadingModels = false
      
  var body: some View {
    NavigationStack {
      Form {
        Section("OpenAI API") {
          SecureField("API Key", text: $openAIAPIKey)
            .textContentType(.password)
        }
        
        Section("WhisperKit Models") {
          if isLoadingModels {
            HStack {
              ProgressView()
              Text("Loading available models...")
                .foregroundColor(.secondary)
            }
          } else {
            Picker("Selected Model", selection: $selectedWhisperModel) {
              ForEach(availableModels, id: \.self) { model in
                HStack {
                  Text(model)
                  if downloadedModels.contains(model) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.green)
                  }
                }
                .tag(model)
              }
            }
            .pickerStyle(.menu)
            
            ForEach(availableModels, id: \.self) { model in
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(model)
                    .font(.headline)
                  Text(WhisperKitWrapper.getModelDescription(for: model))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let progress = downloadProgress[model] {
                  VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: progress)
                      .frame(width: 80)
                    Text("\(Int(progress * 100))%")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                } else if downloadedModels.contains(model) {
                  HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.green)
                    Button("Delete") {
                      Task {
                        await deleteModel(model)
                      }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.red)
                    .disabled(isLoading || selectedWhisperModel == model)
                  }
                } else {
                  Button("Download") {
                    Task {
                      await downloadModel(model)
                    }
                  }
                  .buttonStyle(.borderless)
                  .disabled(isLoading)
                }
              }
            }
            .padding(.vertical, 2)
          }
          }
        }

        Section {
          Button("Start") {
            manager.startActivity()
          }
          Button("Stop") {
            manager.stopActivity()
          }
        }

      }
      .navigationTitle("Settings")
      .task {
        await loadModels()
      }
    }
  }
  
  private func loadModels() async {
    isLoadingModels = true
    
    // Load both available and downloaded models concurrently
    async let fetchedAvailable = WhisperKitWrapper.fetchAvailableModels()
    async let fetchedDownloaded = WhisperKitWrapper.getDownloadedModels()
    
    availableModels = await fetchedAvailable
    downloadedModels = await fetchedDownloaded
    
    isLoadingModels = false
  }
  
  private func loadDownloadedModels() async {
    downloadedModels = await WhisperKitWrapper.getDownloadedModels()
  }
  
  private func downloadModel(_ modelName: String) async {
    isLoading = true
    downloadProgress[modelName] = 0.0
    
    do {
      try await WhisperKitWrapper.downloadModel(modelName) { @Sendable progress in
        Task { @MainActor in
          downloadProgress[modelName] = progress
        }
      }
      downloadProgress.removeValue(forKey: modelName)
      await loadDownloadedModels()
    } catch {
      downloadProgress.removeValue(forKey: modelName)
      // TODO: Show error alert
      print("Failed to download model: \(error)")
    }
    
    isLoading = false
  }
  
  private func deleteModel(_ modelName: String) async {
    isLoading = true
    
    do {
      try await WhisperKitWrapper.deleteModel(modelName)
      await loadDownloadedModels()
    } catch {
      // TODO: Show error alert
      print("Failed to delete model: \(error)")
    }
    
    isLoading = false
  }
}

import ActivityKit
import ActivityContent

@MainActor
final class ActivityManager: ObservableObject {
  
  static let shared = ActivityManager()
  
  private var currentActivity: Activity<MyActivityAttributes>?
  
  private init() {
    
  }
  
  func startActivity() {
    do {
      
      let state = MyActivityAttributes.ContentState(text: "Hello!")
      
      let r = try Activity.request(
        attributes: MyActivityAttributes(),
        content: .init(state: state, staleDate: nil),
        pushType: nil
      )
      
      self.currentActivity = r
    } catch {
      print(error)
    }
  }
  
  func stopActivity(isolation: (any Actor)? = #isolation) {
    Task { @MainActor [currentActivity] in
      await currentActivity?.end(nil)
    }
  }
      
}

#Preview {
  SettingsView()
}
