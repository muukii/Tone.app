import Foundation
import StateGraph
import SwiftData
import AppService

@MainActor
final class AnkiService {
  
  struct ItemDraft {
    var front: String
    var back: String
    var tags: Set<AnkiModels.Tag> = []
  }


  public let modelContainer: ModelContainer

  private let currentSchema: Schema = .init(versionedSchema: AnkiModels.ActiveSchema.self)

  public init() {
    do {
      // got an error in migration plan
      //      let container = try ModelContainer(
      //        for: currentSchema,
      //        migrationPlan: ServiceSchemaMigrationPlan.self,
      //        configurations: .init(url: databasePath)
      //      )
      
      let configuration = ModelConfiguration.init("anki-database", cloudKitDatabase: .private("iCloud.app.muukii.anki"))
      
      let container = try ModelContainer(
        for: currentSchema,
        configurations: configuration
      )
      self.modelContainer = container
    } catch {
      // TODO: delete database if schema mismatches or consider migration
      Log.error("\(error)")
      fatalError()
    }
  }
  
  func delete(tag: AnkiModels.Tag) {
    let context = modelContainer.mainContext
    do {
      try context.transaction {      
        context.delete(tag)
      }
    } catch {
      Log.error("\(error)")
    }
  }

  func delete(item: AnkiModels.ExpressionItem) {
    let context = modelContainer.mainContext
    do {
      try context.transaction {
        context.delete(item)
      }
    } catch {
      Log.error("\(error)")
    }
  }

  func editItem(item: AnkiModels.ExpressionItem, draft: ItemDraft) {
    do {
      let context = modelContainer.mainContext
      item.front = draft.front
      item.back = draft.back
      item.tags = .init(draft.tags)
      try context.save()
    } catch {
      Log.error("\(error)")
    }
  }
  
  func addItem(draft: ItemDraft) {
    do {
      let newItem = AnkiModels.ExpressionItem(
        front: draft.front,
        back: draft.back
      )
      newItem.tags = .init(draft.tags)
      modelContainer.mainContext.insert(newItem)
      try modelContainer.mainContext.save()
    } catch {
      Log.error("\(error)")
    }
  }
  
  /// 本日レビューすべきアイテムを（必要ならタグで絞って）返す
  func itemsForReviewToday(tags: Set<AnkiModels.Tag>? = nil, referenceDate: Date = Date()) -> [AnkiModels.ExpressionItem] {
    let context = modelContainer.mainContext
    let allItems: [AnkiModels.ExpressionItem]
    do {
      let descriptor = FetchDescriptor<AnkiModels.ExpressionItem>()
      allItems = try context.fetch(descriptor)
    } catch {
      Log.error("fetch error: \(error)")
      return []
    }
    
    let filtered = allItems.filter { item in
      let isDue = item.nextReviewAt == nil || item.nextReviewAt! <= referenceDate
      let matchesTag: Bool = {
        guard let tags = tags, !tags.isEmpty else { return true }
        guard let itemTags = item.tags else { return false }
        return itemTags.contains(where: { tags.contains($0) })
      }()
      return isDue && matchesTag
    }
    
    let sorted = filtered.sorted { (a, b) in
      (a.nextReviewAt ?? .distantPast) < (b.nextReviewAt ?? .distantPast)
    }
    
    return sorted
  }
  
  func answer(grade: AnkiModels.ReviewGrade, for item: AnkiModels.ExpressionItem) {    
    do {
      let context = modelContainer.mainContext    
      item.updateReview(grade: grade)
      try context.save()
    } catch {
      assertionFailure("Failed to save: \(error)")
    }
  }
  
}

enum AnkiModels {
  public enum ReviewGrade: Int {
    case again = 1  // 失敗
    case hard = 3  // 難しかった
    case easy = 5  // 簡単だった
  }
  
  public typealias ActiveSchema = V1
  public typealias Tag = ActiveSchema.Tag
  public typealias ExpressionItem = ActiveSchema.ExpressionItem
  
  public enum V1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
      [
        Self.ExpressionItem.self,
        Self.Tag.self,
      ]
    }
    
    @Model
    public nonisolated final class Tag: Hashable, TagType {
      
      public nonisolated var name: String?
      
      public nonisolated var lastUsedAt: Date?
      
      public nonisolated var items: [ExpressionItem]?
      
      public init(name: String) {
        self.name = name
      }
      
      public func markAsUsed() {
        self.lastUsedAt = .init()
      }
    }
    
    @Model
    public nonisolated final class ExpressionItem {
      
      public nonisolated var identifier: String?
      
      @Relationship(deleteRule: .nullify, inverse: \Tag.items)
      public nonisolated var tags: [Tag]?
      
      public nonisolated var front: String?
      public nonisolated var back: String?
      
      // https://super-memory.com/english/ol/sm2.htm
      // spaced repetition用プロパティ
      public nonisolated var easeFactor: Double = 2.5  // E-Factor（最小1.3）
      public nonisolated var interval: Int = 0  // 次回までの間隔（日数）
      public nonisolated var repetition: Int = 0  // 連続正解回数
      
      public nonisolated var lastReviewedAt: Date?  // 最終復習日
      public nonisolated var nextReviewAt: Date?  // 次回復習予定日
      
      public nonisolated var wrappedLastReviewedAt: Date {
        lastReviewedAt ?? Date.init(timeIntervalSince1970: 0)
      }
       
      public nonisolated var wrappedNextReviewAt: Date {
        nextReviewAt ?? Date.init(timeIntervalSince1970: 0)
      }
      
      public init(front: String, back: String) {
        self.identifier = UUID().uuidString
        self.front = front
        self.back = back
      }
      
      /// SuperMemo-2アルゴリズムに基づく復習情報の更新（3択enum対応）
      public func updateReview(grade: ReviewGrade) {
        let quality = grade.rawValue
        let now = Date()
        lastReviewedAt = now
        
        if quality < 3 {
          repetition = 0
          interval = 1
        } else {
          repetition += 1
          switch repetition {
          case 1:
            interval = 1
          case 2:
            interval = 6
          default:
            interval = Int(ceil(Double(interval) * easeFactor))
          }
        }
        
        // E-Factorの更新
        let ef = easeFactor + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        easeFactor = max(1.3, ef)
        
        // 次回復習日
        nextReviewAt = Calendar.current.date(byAdding: .day, value: interval, to: now)
      }
      
      /// 習得度（0.0〜1.0） repetitionとeaseFactorの合成
      public var mastery: Double {
        let repScore = min(Double(repetition) / 10.0, 1.0)
        let efScore = (easeFactor - 1.3) / (3.0 - 1.3)
        return (repScore + efScore) / 2.0
      }
      
      /// 習得度レベル（5段階）
      public enum MasteryLevel: String {
        case level1 // 覚えていない
        case level2 // 初級
        case level3 // 中級
        case level4 // 上級
        case level5 // マスター
      }

      /// mastery値から5段階のMasteryLevelを返す
      public var masteryLevel: MasteryLevel {
        switch mastery {
        case 0.0..<0.2:
          return .level1 // 覚えていない
        case 0.2..<0.4:
          return .level2 // 初級
        case 0.4..<0.6:
          return .level3 // 中級
        case 0.6..<0.8:
          return .level4 // 上級
        default:
          return .level5 // マスター
        }
      }
          
    }
    
  }
}
