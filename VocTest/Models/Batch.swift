import Foundation
import SwiftData

/// 單字批次：資料階層中層（Deck → Batch → Card）。
/// 匯入時每 `CardImporter.chunkSize` 張卡自動切成一批，是複習與測驗的基本單位；
/// 同一個數字也是手動新增的容量上限。
@Model
final class Batch {
    /// 批次在所屬分組內的顯示編號（由 1 起）。刻意開放為可寫，
    /// 以便 `Deck.reindexBatches()` 在刪除批次後重新編號。
    var index: Int
    /// 建立時間。
    var createdAt: Date
    /// 所屬分組；批次一定隸屬於某個 Deck。
    var deck: Deck?

    /// 此批次底下的卡片。`private(set)` 使外部無法直接改寫陣列，
    /// 只能透過 SwiftData 反向關聯（設定 `card.batch = self`）加入。
    /// 刪除批次時級聯刪除其卡片。
    @Relationship(deleteRule: .cascade, inverse: \Card.batch)
    private(set) var cards: [Card] = []

    init(index: Int, createdAt: Date = Date()) {
        self.index = index
        self.createdAt = createdAt
    }
}
