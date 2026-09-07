import Foundation
import SwiftData

/// 文法分組：文法側資料階層最上層（GrammarDeck → GrammarBatch → GrammarItem），
/// 與單字側的 `Deck` 對稱。
@Model
final class GrammarDeck {
    /// 分組名稱，由使用者建立時輸入。
    var name: String
    /// 建立時間，用於列表排序。
    var createdAt: Date

    /// 此分組底下的所有批次。刪除分組時級聯刪除其批次（及批次底下的題目）。
    @Relationship(deleteRule: .cascade, inverse: \GrammarBatch.deck)
    var grammarBatches: [GrammarBatch] = []

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }

    /// 重新編號剩餘批次，讓 index 由 1 起連續遞增且保留原有相對順序。
    /// 於任何會移除批次的操作（刪整批、刪光某批後移除空批次）之後呼叫。
    func reindexBatches() {
        let ordered = grammarBatches.sorted { $0.index < $1.index }
        for (offset, batch) in ordered.enumerated() {
            batch.index = offset + 1
        }
    }
}
