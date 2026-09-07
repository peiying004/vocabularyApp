import Foundation
import SwiftData

/// 單字卡：資料階層最底層（Deck → Batch → Card），代表一張要測驗的單字。
@Model
final class Card {
    /// 單字本身。
    var word: String
    /// 詞性（可選，例如 "n."、"v."）。
    var partOfSpeech: String?
    /// 中文翻譯。
    var translation: String
    /// 累計答錯次數。`private(set)` 使外部只能透過 `recordWrong()` 遞增，無法任意改寫。
    private(set) var wrongCount: Int
    /// 匯入時在批次內的原始順序，供預習／測驗依序呈現。
    var importOrder: Int
    /// 所屬批次。
    var batch: Batch?

    init(
        word: String,
        partOfSpeech: String?,
        translation: String,
        importOrder: Int
    ) {
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.translation = translation
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
