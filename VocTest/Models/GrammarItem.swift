import Foundation
import SwiftData

/// 文法題：文法側資料階層最底層（GrammarDeck → GrammarBatch → GrammarItem），
/// 代表一道單選題。測驗時的選項來自「正解 + 誘答」。
@Model
final class GrammarItem {
    /// 題目敘述（通常含填空）。
    var question: String
    /// 正確答案。
    var correct: String
    /// 誘答選項（錯誤選項）；與 `correct` 合併、打散後成為測驗的四個選項。
    var distractors: [String]
    /// 詳解（可選）。
    var explanation: String?
    /// 累計答錯次數。`private(set)` 使外部只能透過 `recordWrong()` 遞增。
    private(set) var wrongCount: Int
    /// 匯入時在批次內的原始順序，供預習／測驗依序呈現。
    var importOrder: Int
    /// 所屬批次。
    var batch: GrammarBatch?

    init(
        question: String,
        correct: String,
        distractors: [String],
        explanation: String?,
        importOrder: Int
    ) {
        self.question = question
        self.correct = correct
        self.distractors = distractors
        self.explanation = explanation
        self.wrongCount = 0
        self.importOrder = importOrder
    }

    /// 答錯時呼叫，累計錯誤次數（只增不減）。
    func recordWrong() {
        wrongCount += 1
    }

    /// 把累計錯誤次數歸零。只在使用者於批次首頁明確觸發「重算錯誤次數」時呼叫；
    /// 編輯、新增、刪除內容都不會自動呼叫。與 `recordWrong()` 同為具名入口，
    /// 使 `wrongCount` 得以維持 `private(set)`，不開放任意寫入。
    func resetWrongCount() {
        wrongCount = 0
    }
}
