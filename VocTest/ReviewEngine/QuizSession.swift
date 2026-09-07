import Foundation
import SwiftData

/// 使用者對單一題目所做的選擇。
/// `.translation` 代表點選了某個翻譯選項，`.dontKnow` 代表點選「不知道」。
enum Choice: Equatable {
    case translation(String)
    case dontKnow
}

/// 一次作答的判定結果。
/// 答錯時會夾帶正確翻譯，供 UI 立即回饋顯示。
enum AnswerResult: Equatable {
    case correct
    case wrong(correctTranslation: String)
}

/// 一輪測驗結束後的統計摘要。
/// `correctCount` 為答對的卡片數（本輪總數扣除曾答錯的卡片數），
/// `wrongTaps` 為累計答錯次數（同一張卡片可能重複計入），
/// `mistakeCards` 為本輪曾答錯過的卡片清單。
struct ResultSummary: Equatable {
    let correctCount: Int
    let wrongTaps: Int
    let mistakeCards: [Card]
}

/// 單字測驗的一輪狀態機。
///
/// 以 `remaining` 佇列驅動測驗流程：隊首即為目前題目，答對則移除，
/// 答錯則將該卡片重新插回佇列後方（間隔數張），直到佇列清空才算本輪結束。
/// 同時追蹤答錯次數與曾答錯的卡片，供結束時產生 `ResultSummary`。
final class QuizSession {
    /// 尚待作答的卡片佇列；隊首 (`first`) 即為目前題目。答錯的卡片會被重新插回此佇列。
    private(set) var remaining: [Card]
    /// 本輪起始的卡片總數，用於計算答對數；不受答錯重新入列影響。
    let totalCardsInRound: Int
    /// 累計答錯次數；同一張卡片重複答錯會多次累加。
    private(set) var wrongTapCount: Int = 0
    /// 曾答錯的卡片 ID，依首次答錯順序保存。
    private var mistakeCardIDs: [PersistentIdentifier] = []
    /// 用於快速去重，確保同一張卡片只被視為一次錯誤（供摘要計數）。
    private var mistakeCardIDSet: Set<PersistentIdentifier> = []

    private let batch: Batch

    /// Test-friendly initializer: explicit card queue, no shuffling.
    init(cards: [Card], batch: Batch, totalCardsInRound: Int? = nil) {
        self.batch = batch
        self.remaining = cards
        self.totalCardsInRound = totalCardsInRound ?? cards.count
    }

    /// Production initializer: draw min(sampleSize, batch.cards.count) at random.
    /// 預設值取自批次容量，使一輪測驗涵蓋整批；容量調整時不需同步改這裡。
    convenience init(batch: Batch, sampleSize: Int = CardImporter.chunkSize) {
        let shuffled = batch.cards.shuffled()
        let count = Swift.min(sampleSize, shuffled.count)
        self.init(
            cards: Array(shuffled.prefix(count)),
            batch: batch,
            totalCardsInRound: count
        )
    }

    /// 目前題目：佇列隊首，佇列為空時為 nil。
    var currentCard: Card? { remaining.first }
    /// 佇列清空即代表本輪結束。
    var isFinished: Bool { remaining.isEmpty }

    /// Four translation choices for the current question, shuffled.
    /// One is the correct translation; three are distractors.
    func choicesForCurrent() -> [String] {
        guard let current = remaining.first else { return [] }
        var pool = pickDistractors(for: current)
        pool.append(current.translation)
        pool.shuffle()
        return pool
    }

    /// Three distractor translations, drawn from the same batch first,
    /// falling back to other batches in the deck if the batch is too small.
    func pickDistractors(for card: Card) -> [String] {
        var chosen: [String] = []
        var taken = Set<String>([card.translation])

        let sameBatch = batch.cards
            .filter { $0 !== card && $0.translation != card.translation }
            .map(\.translation)
            .shuffled()
        for t in sameBatch where !taken.contains(t) {
            chosen.append(t)
            taken.insert(t)
            if chosen.count == 3 { return chosen }
        }

        if let deck = batch.deck, chosen.count < 3 {
            let otherBatchTranslations = deck.batches
                .filter { $0 !== batch }
                .flatMap(\.cards)
                .map(\.translation)
                .shuffled()
            for t in otherBatchTranslations where !taken.contains(t) {
                chosen.append(t)
                taken.insert(t)
                if chosen.count == 3 { return chosen }
            }
        }
        return chosen
    }

    /// Submit the user's selected answer for the current card.
    /// Returns whether the answer was correct, and on wrong answers
    /// re-queues the card with a gap.
    @discardableResult
    func submit(_ choice: Choice) -> AnswerResult {
        guard let card = remaining.first else { return .correct }

        let isCorrect: Bool
        switch choice {
        case .translation(let t) where t == card.translation:
            isCorrect = true
        case .translation, .dontKnow:
            isCorrect = false
        }

        if isCorrect {
            remaining.removeFirst()  // 答對：直接移出佇列，不再出現
            return .correct
        } else {
            card.recordWrong()
            wrongTapCount += 1
            // 首次答錯才登記為錯誤卡片（去重），避免重複計入摘要
            if mistakeCardIDSet.insert(card.persistentModelID).inserted {
                mistakeCardIDs.append(card.persistentModelID)
            }
            remaining.removeFirst()
            // 答錯：將卡片重新插回佇列後方，間隔最多 3 張再次出題；
            // 剩餘不足 3 張時插到隊尾，確保本輪一定會再問一次
            let gap = Swift.min(remaining.count, 3)
            remaining.insert(card, at: gap)
            return .wrong(correctTranslation: card.translation)
        }
    }

    /// 產生本輪測驗摘要。錯誤卡片依匯入順序 (`importOrder`) 排序，
    /// 答對數為本輪總數扣除去重後的錯誤卡片數。
    func resultSummary() -> ResultSummary {
        let mistakeCards = batch.cards
            .filter { mistakeCardIDSet.contains($0.persistentModelID) }
            .sorted { $0.importOrder < $1.importOrder }
        return ResultSummary(
            correctCount: totalCardsInRound - mistakeCards.count,
            wrongTaps: wrongTapCount,
            mistakeCards: mistakeCards
        )
    }
}
