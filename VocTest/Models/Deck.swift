import Foundation
import SwiftData

/// 單字分組：資料階層最上層（Deck → Batch → Card）。
/// 一個分組代表一組主題單字（例如「TOEIC 常考」），底下含多個批次。
@Model
final class Deck {
    /// 分組名稱，由使用者建立時輸入。
    var name: String
    /// 建立時間，用於列表排序。
    var createdAt: Date

    /// 此分組底下的所有批次。刪除分組時一併級聯刪除其批次（及批次底下的卡片）。
    @Relationship(deleteRule: .cascade, inverse: \Batch.deck)
    var batches: [Batch] = []

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }

    /// 重新編號剩餘批次，讓 index 由 1 起連續遞增且保留原有相對順序。
    /// 於任何會移除批次的操作（刪整批、刪光某批後移除空批次）之後呼叫。
    func reindexBatches() {
        let ordered = batches.sorted { $0.index < $1.index }
        for (offset, batch) in ordered.enumerated() {
            batch.index = offset + 1
        }
    }
}
