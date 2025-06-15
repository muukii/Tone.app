import AppService
import ObjectEdge
import StateGraph
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import UIComponents

struct AudioImportView: View {

  private let service: Service
  private let targetFiles: [TargetFile]
  @Query private var allTags: [TagEntity]
  @State private var editingTarget: TargetFile?
  @State private var showBatchTagPicker = false
  @State private var batchTags: [TagEntity] = []
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
              Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
              
              VStack(alignment: .leading, spacing: 4) {
                Text(target.name)
                  .font(.system(size: 16, weight: .medium))
                  .lineLimit(1)
                
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
      }
      .navigationTitle("Import \(targetFiles.count) Files")
      .navigationBarTitleDisplayMode(.large)
      .safeAreaInset(edge: .bottom) { 
        VStack(spacing: 0) {
          Divider()
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Ready to import")
                .font(.system(size: 14, weight: .medium))
              Text("\(targetFiles.count) files • \(totalTagCount) tags")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
              for target in targetFiles {
                _ = service.enqueueTranscribe(
                  target: target,
                  additionalTags: batchTags
                )
              }
              onSubmit()
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
            Text("Apply tags to all files at once")
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

struct ImportTagPicker: View {
  @Binding var targetFile: TargetFile
  let allTags: [TagEntity]
  let service: Service
  let modelContext: ModelContext
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    TagEditorInnerView(
      nameKeyPath: \.name,
      currentTags: targetFile.tags,
      allTags: allTags,
      onAddTag: { tag in
        if !targetFile.tags.contains(where: { $0.id == tag.id }) {
          targetFile.tags.append(tag)
        }
      },
      onRemoveTag: { tag in
        targetFile.tags.removeAll { $0.id == tag.id }
      },
      onCreateTag: { name in
        guard let newTag = try? service.createTag(name: name) else {
          fatalError("Failed to create tag")
        }
        return newTag
      }
    )
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          dismiss()
        }
      }
    }
  }
}


struct BatchTagPicker: View {
  @Binding var batchTags: [TagEntity]
  let allTags: [TagEntity]
  let service: Service
  let modelContext: ModelContext
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    VStack(spacing: 20) {
      TagEditorInnerView(
        nameKeyPath: \.name,
        currentTags: batchTags,
        allTags: allTags,
        onAddTag: { tag in
          if !batchTags.contains(where: { $0.id == tag.id }) {
            batchTags.append(tag)
          }
        },
        onRemoveTag: { tag in
          batchTags.removeAll { $0.id == tag.id }
        },
        onCreateTag: { name in
          guard let newTag = try? service.createTag(name: name) else {
            fatalError("Failed to create tag")
          }
          return newTag
        }
      )
    }
    .navigationTitle("Select Tags for All Files")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          dismiss()
        }
        .fontWeight(.medium)
      }
    }
  }
}

#Preview {
  AudioImportView(
    service: .init(),
    targets: [
      .init(
        name: "",
        url: .init(filePath: "")!
      )
    ],
    onSubmit: {      
    }
  )
}
