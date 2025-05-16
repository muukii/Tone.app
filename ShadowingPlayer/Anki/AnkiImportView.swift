import SwiftUI
import TabularData
import UniformTypeIdentifiers

struct AnkiImportView: View {
  
  @Environment(\.modelContext) private var modelContext
  @State private var isImporterPresented = false
  @State private var importResult: String?

  var body: some View {
    VStack(spacing: 20) {
      Button("CSVをインポート") {
        isImporterPresented = true
      }
      .fileImporter(
        isPresented: $isImporterPresented,
        allowedContentTypes: [.commaSeparatedText],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls):
          if let url = urls.first {
            importCSV(from: url)
          }
        case .failure(let error):
          importResult = "ファイル選択エラー: \(error.localizedDescription)"
        }
      }

      if let importResult {
        Text(importResult)
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }

  func importCSV(from url: URL) {
    do {
      
      let df = try DataFrame(contentsOfCSVFile: url, options: .init(hasHeaderRow: true))
            
      var models: [AnkiModels.ExpressionItem] = []
      
      for row in df.rows {
        
        guard let front = row[0] as? String, let back = row[1] as? String else {
          continue
        }
                
        let item = AnkiModels.ExpressionItem(front: front, back: back)
        models.append(item)
      }
      
      for model in models {
        modelContext.insert(model)
      }

      try? modelContext.save()
      importResult = "\(models.count)件インポートしました"
    } catch {
      importResult = "CSV読み込みエラー: \(error.localizedDescription)"
    }
  }
} 
