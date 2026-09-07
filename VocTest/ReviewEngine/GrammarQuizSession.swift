import Foundation
import SwiftData

/// 一輪文法測驗結束後的統計摘要。
/// `correctCount` 為答對題數（本輪總數扣除曾答錯題數），
/// `wrongTaps` 為累計答錯次數，`mistakeItems` 為曾答錯的文法題清單。
struct GrammarResultSummary: Equatable {
    let correctCount: Int
    let wrongTaps: Int
    let mistakeItems: [GrammarItem]
}

/// 文法測驗的一輪狀態機。
///
/// 運作方式與 `QuizSession` 相同：以 `remaining` 佇列驅動，答對移除、
/// 答錯則重新插回佇列後方（間隔數題），佇列清空即結束本輪。
/// 差異在於選項僅取自題目本身內建的正解與誘答，不跨題抽樣。
final class GrammarQuizSession {
    /// 尚待作答的文法題佇列；隊首即為目前題目。答錯的題目會被重新插回。
    private(set) var remaining: [GrammarItem]
    /// 本輪起始題數，用於計算答對數；不受答錯重新入列影響。
    let totalItemsInRound: Int
    /// 累計答錯次數；同一題重複答錯會多次累加。
    private(set) var wrongTapCount: Int = 0
    /// 曾答錯的題目 ID，依首次答錯順序保存。
    private var mistakeItemIDs: [PersistentIdentifier] = []
    /// 用於去重，確保同一題只被視為一次錯誤。
    private var mistakeItemIDSet: Set<PersistentIdentifier> = []

    private let batch: GrammarBatch

    /// 測試用初始化：明確指定題目佇列，不做洗牌。
    init(items: [GrammarItem], batch: GrammarBatch, totalItemsInRound: Int? = nil) {
        self.batch = batch
        self.remaining = items
        self.totalItemsInRound = totalItemsInRound ?? items.count
    }

    /// 正式初始化：從批次中隨機抽取 min(sampleSize, 題數) 題出題。
    /// 預設值取自批次容量，使一輪測驗涵蓋整批；容量調整時不需同步改這裡。
    convenience init(batch: GrammarBatch, sampleSize: Int = GrammarItemImporter.chunkSize) {
        let shuffled = batch.items.shuffled()
        let count = Swift.min(sampleSize, shuffled.count)
        self.init(
            items: Array(shuffled.prefix(count)),
            batch: batch,
            totalItemsInRound: count
        )
    }

    /// 目前題目：佇列隊首，佇列為空時為 nil。
    var currentItem: GrammarItem? { remaining.first }
    /// 佇列清空即代表本輪結束。
    var isFinished: Bool { remaining.isEmpty }

    /// Four choices assembled from the current item's own correct + distractors.
    /// Never samples from other items.
    func choicesForCurrent() -> [String] {
        guard let current = remaining.first else { return [] }
        var pool = current.distractors
        pool.append(current.correct)
        pool.shuffle()
        return pool
    }

    /// 提交目前題目的作答。回傳是否答對；答錯時將題目重新插回佇列後方（間隔數題）。
    @discardableResult
    func submit(_ choice: Choice) -> AnswerResult {
        guard let item = remaining.first else { return .correct }

        let isCorrect: Bool
        switch choice {
        case .translation(let t) where t == item.correct:
            isCorrect = true
        case .translation, .dontKnow:
            isCorrect = false
        }

        if isCorrect {
            remaining.removeFirst()  // 答對：直接移出佇列，不再出現
            return .correct
        } else {
            item.recordWrong()
            wrongTapCount += 1
            // 首次答錯才登記為錯誤題（去重），避免重複計入摘要
            if mistakeItemIDSet.insert(item.persistentModelID).inserted {
                mistakeItemIDs.append(item.persistentModelID)
            }
            remaining.removeFirst()
            // 答錯：重新插回佇列後方，間隔最多 3 題再次出題；
            // 剩餘不足 3 題時插到隊尾，確保本輪一定會再問一次
            let gap = Swift.min(remaining.count, 3)
            remaining.insert(item, at: gap)
            return .wrong(correctTranslation: item.correct)
        }
    }

    /// 產生本輪測驗摘要。錯誤題目依匯入順序 (`importOrder`) 排序，
    /// 答對數為本輪總數扣除去重後的錯誤題數。
    func resultSummary() -> GrammarResultSummary {
        let mistakeItems = batch.items
            .filter { mistakeItemIDSet.contains($0.persistentModelID) }
            .sorted { $0.importOrder < $1.importOrder }
        return GrammarResultSummary(
            correctCount: totalItemsInRound - mistakeItems.count,
            wrongTaps: wrongTapCount,
            mistakeItems: mistakeItems
        )
    }
}
