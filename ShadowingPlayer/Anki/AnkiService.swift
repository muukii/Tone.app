import Foundation
import StateGraph
import SwiftData

final class AnkiService {

  public let modelContainer: ModelContainer

  private let currentSchema: Schema = .init(versionedSchema: AnkiModels.ActiveSchema.self)

  public init() {
    let databasePath = URL.documentsDirectory.appending(path: "anki-database")
    do {
      // got an error in migration plan
      //      let container = try ModelContainer(
      //        for: currentSchema,
      //        migrationPlan: ServiceSchemaMigrationPlan.self,
      //        configurations: .init(url: databasePath)
      //      )
      let container = try ModelContainer(
        for: currentSchema,
        configurations: .init(url: databasePath)
      )
      self.modelContainer = container
    } catch {
      // TODO: delete database if schema mismatches or consider migration
      Log.error("\(error)")
      fatalError()
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
    public final class Tag: Hashable {
      
      @Attribute(.unique)
      public var name: String
      
      public var lastUsedAt: Date?
      
      public init(name: String) {
        self.name = name
      }
      
      public func markAsUsed() {
        self.lastUsedAt = .init()
      }
    }
    
    @Model
    public final class ExpressionItem {
      
      @Attribute(.unique)
      public var identifier: String
      
      public var tags: [Tag] = []
      
      public var front: String
      public var back: String
      
      // https://super-memory.com/english/ol/sm2.htm
      // spaced repetition用プロパティ
      public var easeFactor: Double = 2.5  // E-Factor（最小1.3）
      public var interval: Int = 0  // 次回までの間隔（日数）
      public var repetition: Int = 0  // 連続正解回数
      public var lastReviewedAt: Date?  // 最終復習日
      public var nextReviewAt: Date?  // 次回復習予定日
      
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
      
      /// SwiftDataで本日レビューすべきアイテムを取得する
      public static func fetchItemsToReviewToday(
        context: ModelContext, referenceDate: Date = Date()
      ) throws -> [ExpressionItem] {
        let descriptor = FetchDescriptor<ExpressionItem>(
          predicate: #Predicate { item in
            item.nextReviewAt == nil || item.nextReviewAt! <= referenceDate
          },
          sortBy: [
            SortDescriptor(\.nextReviewAt, order: .forward)
          ]
        )
        return try context.fetch(descriptor)
      }
    }
    
  }
}
