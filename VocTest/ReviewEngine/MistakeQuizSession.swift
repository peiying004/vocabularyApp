import Foundation

/// 錯題複習的工廠。
///
/// 不另建狀態機，而是重用 `QuizSession` 引擎，只把佇列改由「上一輪答錯的卡片」種入，
/// 讓使用者針對錯題再測一輪。答錯重新入列、round 結束等行為皆沿用 `QuizSession`。
enum MistakeQuiz {

    /// Build a QuizSession seeded with the previous round's mistake cards.
    /// Distractors and re-queue behavior are inherited from QuizSession,
    /// which already draws distractors from the full batch — so the pool
    /// does not collapse to "guess between the cards you missed".
    static func session(from mistakeCards: [Card], in batch: Batch) -> QuizSession {
        QuizSession(
            cards: mistakeCards,
            batch: batch,
            totalCardsInRound: mistakeCards.count
        )
    }
}
