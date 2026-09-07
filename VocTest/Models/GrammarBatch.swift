import Foundation
import SwiftData

/// 文法批次：文法側資料階層中層（GrammarDeck → GrammarBatch → GrammarItem），
/// 與單字側的 `Batch` 對稱。匯入時每 `GrammarItemImporter.chunkSize` 題自動切成一批；
/// 同一個數字也是手動新增的容量上限。
@Model
final class GrammarBatch {
    /// 批次在所屬分組內的顯示編號（由 1 起）。刻意開放為可寫，
    /// 以便 `GrammarDeck.reindexBatches()` 在刪除批次後重新編號。
    var index: Int
    /// 建立時間。
    var createdAt: Date
    /// 所屬分組；批次一定隸屬於某個 GrammarDeck。
    var deck: GrammarDeck?

    /// 此批次底下的題目。`private(set)` 使外部無法直接改寫陣列，
    /// 只能透過 SwiftData 反向關聯（設定 `item.batch = self`）加入。
    /// 刪除批次時級聯刪除其題目。
    @Relationship(deleteRule: .cascade, inverse: \GrammarItem.batch)
    private(set) var items: [GrammarItem] = []

    init(index: Int, createdAt: Date = Date()) {
        self.index = index
        self.createdAt = createdAt
    }
}
