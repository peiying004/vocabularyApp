import Foundation
import SwiftData

/// 把解析後的單字（`ParsedCard`）寫入某個 `Deck`。
/// 負責「切批」：每 `chunkSize` 張卡自動成為一個 `Batch`，並延續該 deck
/// 既有的批次編號繼續往下編。純資料層邏輯，不涉及 UI。
enum CardImporter {

    /// 單字側每一批的固定張數，同時是手動新增的硬上限（見 `CardEditor.capacity`）。
    /// 文法側對應的常數是 `GrammarItemImporter.chunkSize`，兩者刻意同值。
    static let chunkSize = 40

    /// 把 `parsed` 依 `chunkSize` 切批後接續寫入 `deck`。
    /// - 回傳這次新建立的批次（依建立順序）。空輸入回傳空陣列、不建任何批次。
    @discardableResult
    static func appendCards(
        _ parsed: [ParsedCard],
        to deck: Deck,
        in context: ModelContext
    ) -> [Batch] {
        guard !parsed.isEmpty else { return [] }

        // 接續既有最大批次編號往下編，讓多次匯入的批次編號連續不重疊。
        let nextIndex = (deck.batches.map(\.index).max() ?? 0) + 1
        var newBatches: [Batch] = []

        let chunks = parsed.chunked(into: chunkSize)
        for (i, chunk) in chunks.enumerated() {
            let batch = Batch(index: nextIndex + i)
            batch.deck = deck
            context.insert(batch)
            // importOrder 記錄卡片在批次內的原始順序，供預習／測驗排序使用。
            for (j, p) in chunk.enumerated() {
                let card = Card(
                    word: p.word,
                    partOfSpeech: p.partOfSpeech,
                    translation: p.translation,
                    importOrder: j
                )
                card.batch = batch
                context.insert(card)
            }
            newBatches.append(batch)
        }
        return newBatches
    }
}
