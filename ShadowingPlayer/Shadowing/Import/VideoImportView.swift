import AppService
import SwiftUI
import SwiftData
import UIComponents

struct VideoImportView: View {
  
  private let service: Service
  private let targetFiles: [TargetFile]
  @Query private var allTags: [TagEntity]
  @State private var editingTarget: TargetFile?
  @State private var showBatchTagPicker = false
  @State private var batchTags: [TagEntity] = []
  @State private var customTitles: [UUID: String] = [:]
  @Environment(\.modelContext) private var modelContext
  let onSubmit: @MainActor () -> Void
  
  init(
    service: Service,
    targets: [TargetFile],
    onSubmit: @escaping @MainActor () -> Void
  ) {
    self.service = service
    self.targetFiles = targets
    self.onSubmit = onSubmit
  }
  
  private var totalTagCount: Int {
    Set(targetFiles.flatMap { $0.tags }).count
  }
  
  var body: some View {
    
    NavigationStack {
      List {
        
        batchTagSection
        
        ForEach(targetFiles) { target in
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Image(systemName: "video.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
              
              VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: titleBinding(for: target))
                  .font(.system(size: 16, weight: .medium))
                  .textFieldStyle(.roundedBorder)
                
                Text("\(target.tags.count) tags")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
              }
              
              Spacer()
              
              Button {
                editingTarget = target
              } label: {
                Image(systemName: "tag")
                  .font(.system(size: 18))
                  .foregroundColor(.accentColor)
              }
            }
            
            if !target.tags.isEmpty {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(target.tags) { tag in
                    if let name = tag.name {
                      HStack(spacing: 4) {
                        Text(name)
                          .font(.system(size: 13, weight: .medium))
                          .foregroundColor(.primary)
                        Button {
                          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            target.tags.removeAll { $0.id == tag.id }
                          }
                        } label: {
                          Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        }
                      }
                      .padding(.horizontal, 10)
                      .padding(.vertical, 5)
                      .background(
                        Capsule()
                          .fill(Color(.systemGray5))
                      )
                    }
                  }
                }
              }
            }
            
          }
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color(.systemBackground))
              .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
          )
          .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
        }
      }
      .listStyle(.plain)
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Import \(targetFiles.count) Videos")
      .navigationBarTitleDisplayMode(.large)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 0) {
          Divider()
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Ready to import")
                .font(.system(size: 14, weight: .medium))
              Text("\(targetFiles.count) videos • \(totalTagCount) tags")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
              Task {
                for target in targetFiles {
                  let title = customTitles[target.id] ?? target.name
                  _ = service.enqueueVideoTranscribe(
                    target: TargetFile(
                      name: title,
                      url: target.url,
                      tags: target.tags
                    ),
                    additionalTags: batchTags
                  )
                }
                onSubmit()
              }
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Import")
              }
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 24)
              .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
          }
          .padding()
          .background(Color(.systemBackground))
        }
      }
      .sheet(item: $editingTarget, content: sheetTag)
      .sheet(isPresented: $showBatchTagPicker, content: sheetTagForAll)
    }
  }
  
  private func titleBinding(for target: TargetFile) -> Binding<String> {
    Binding(
      get: { customTitles[target.id] ?? target.name },
      set: { customTitles[target.id] = $0 }
    )
  }
  
  private func sheetTagForAll() -> some View {
    TagEditorView(
      service: service,
      currentTags: batchTags,
      allTags: allTags,
      onAddTag: { tag in
        batchTags.append(tag)
      },
      onRemoveTag: { tag in
        batchTags.removeAll(where: { $0 == tag })
      }
    )
    .presentationDetents([.medium, .large])
  }
  
  private func sheetTag(for target: TargetFile) -> some View {
    TagEditorView(
      service: service,
      currentTags: target.tags,
      allTags: allTags,
      onAddTag: { tag in
        target.tags.append(tag)
      },
      onRemoveTag: { tag in
        target.tags.removeAll(where: { $0 == tag })
      }
    )
    .presentationDetents([.medium, .large])
  }
  
  @ViewBuilder
  private var batchTagSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Batch Tags")
              .font(.system(size: 18, weight: .semibold))
            Text("Apply tags to all videos at once")
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }
          Spacer()
          Button {
            showBatchTagPicker = true
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 24))
              .foregroundColor(.accentColor)
          }
        }
        
        if !batchTags.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(batchTags) { tag in
                  if let name = tag.name {
                    HStack(spacing: 6) {
                      Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                      Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                          batchTags.removeAll { $0.id == tag.id }
                        }
                      } label: {
                        Image(systemName: "xmark")
                          .font(.system(size: 10, weight: .bold))
                          .foregroundColor(.white.opacity(0.8))
                      }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                      LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                  }
                }
              }
            }
          }
        }
      }
      .padding(.vertical, 8)
    }
    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .listRowBackground(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemGray6))
    )
  }
}