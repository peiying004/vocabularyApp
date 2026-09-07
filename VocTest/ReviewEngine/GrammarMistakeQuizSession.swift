import Foundation

/// 文法錯題複習的工廠。
///
/// 重用 `GrammarQuizSession` 引擎，將佇列改由上一輪答錯的文法題種入，並先洗牌打散順序。
/// 保留原批次 (`batch`)，讓摘要階段能正確地將 persistent identifier 對應回該批次的題目。
enum GrammarMistakeQuiz {
    /// Build a session that reuses the standard `GrammarQuizSession` engine but seeds
    /// its queue from the provided mistake items. The batch is preserved so the summary
    /// still resolves persistent identifiers to items owned by that batch.
    static func session(from mistakeItems: [GrammarItem], in batch: GrammarBatch) -> GrammarQuizSession {
        GrammarQuizSession(
            items: mistakeItems.shuffled(),
            batch: batch,
            totalItemsInRound: mistakeItems.count
        )
    }
}
