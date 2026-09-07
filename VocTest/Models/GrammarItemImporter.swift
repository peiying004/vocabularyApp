import Foundation
import SwiftData

/// 把解析後的文法題（`ParsedGrammarItem`）寫入某個 `GrammarDeck`。
/// 與 `CardImporter` 對稱：每 `chunkSize` 題自動成為一個 `GrammarBatch`，
/// 並延續該 deck 既有的批次編號往下編。純資料層邏輯，不涉及 UI。
enum GrammarItemImporter {

    /// 文法側每一批的固定題數，同時是手動新增的硬上限（見 `GrammarItemEditor.capacity`）。
    /// 單字側對應的常數是 `CardImporter.chunkSize`，兩者刻意同值。
    static let chunkSize = 40

    /// 把 `parsed` 依 `chunkSize` 切批後接續寫入 `deck`。
    /// - 回傳這次新建立的批次（依建立順序）。空輸入回傳空陣列、不建任何批次。
    @discardableResult
    static func appendItems(
        _ parsed: [ParsedGrammarItem],
        to deck: GrammarDeck,
        in context: ModelContext
    ) -> [GrammarBatch] {
        guard !parsed.isEmpty else { return [] }

        // 接續既有最大批次編號往下編，讓多次匯入的批次編號連續不重疊。
        let nextIndex = (deck.grammarBatches.map(\.index).max() ?? 0) + 1
        var newBatches: [GrammarBatch] = []

        let chunks = parsed.chunked(into: chunkSize)
        for (i, chunk) in chunks.enumerated() {
            let batch = GrammarBatch(index: nextIndex + i)
            batch.deck = deck
            context.insert(batch)
            // importOrder 記錄題目在批次內的原始順序，供預習／測驗排序使用。
            for (j, p) in chunk.enumerated() {
                let item = GrammarItem(
                    question: p.question,
                    correct: p.correct,
                    distractors: p.distractors,
                    explanation: p.explanation,
                    importOrder: j
                )
                item.batch = batch
                context.insert(item)
            }
            newBatches.append(batch)
        }
        return newBatches
    }
}
