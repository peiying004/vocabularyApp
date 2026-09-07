import Foundation
import SwiftData

/// 對既有 `Batch` 內的單字卡做「驗證／新增／刪除」的資料層邏輯。
/// 與 `CardImporter` 對稱：`CardImporter` 負責匯入時的切批寫入，
/// `CardEditor` 負責匯入之後在單一批次內的增刪。純資料層，不涉及 UI。
enum CardEditor {

    /// 單一批次可容納的卡片上限。沿用匯入的切批數量，
    /// 使匯入的切批張數對手動新增同樣是硬上限。
    static var capacity: Int { CardImporter.chunkSize }

    /// 驗證卡片欄位是否可儲存，規則與 `MarkdownParser` 的必填規則一致：
    /// 單字與翻譯去除前後空白後必須非空；詞性可省略。
    static func isValid(word: String, translation: String) -> Bool {
        !word.trimmingCharacters(in: .whitespaces).isEmpty
            && !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 該批次是否還能再新增一張卡（未達 `capacity`）。
    static func canAppend(to batch: Batch) -> Bool {
        batch.cards.count < capacity
    }

    /// 該批次還能再放幾張卡。已滿時為 0，不會是負數。
    static func remainingCapacity(of batch: Batch) -> Int {
        Swift.max(0, capacity - batch.cards.count)
    }

    /// 批量寫入的結果統計。
    struct BulkAppendResult: Equatable {
        /// 寫進目標批次的張數。
        let addedToBatch: Int
        /// 因溢出而新建立的批次數。
        let newBatchesCreated: Int
        /// 本次總共寫入的張數。
        let totalAdded: Int
    }

    /// 把多筆解析結果寫入既有批次：先填滿目標批次，其餘視 `allowingOverflow` 決定去留。
    /// 溢出的部分交給 `CardImporter.appendCards`，因此切批與編號規則與匯入完全一致。
    /// - Parameter allowingOverflow: 為 false 且內容超過剩餘容量時，不寫入任何一筆並回傳 nil。
    /// - Returns: 寫入統計；被拒絕時為 nil。
    @discardableResult
    static func appendCards(
        _ parsed: [ParsedCard],
        to batch: Batch,
        allowingOverflow: Bool,
        in context: ModelContext
    ) -> BulkAppendResult? {
        // 防禦性過濾：正常情況下解析器已保證通過，但批量路徑不該比單筆路徑寬鬆。
        let valid = parsed.filter { isValid(word: $0.word, translation: $0.translation) }
        let room = remainingCapacity(of: batch)

        // 會不會溢出、能不能溢出，都在寫入任何一筆之前判斷完畢，
        // 避免出現「填了一半才發現放不下」的部分寫入狀態。
        if valid.count > room {
            guard allowingOverflow, batch.deck != nil else { return nil }
        }

        let fitting = Array(valid.prefix(room))
        var nextOrder = (batch.cards.map(\.importOrder).max() ?? -1) + 1
        for p in fitting {
            let card = Card(
                word: p.word,
                partOfSpeech: normalizedOptional(p.partOfSpeech),
                translation: p.translation,
                importOrder: nextOrder
            )
            card.batch = batch
            context.insert(card)
            nextOrder += 1
        }

        let overflow = Array(valid.dropFirst(room))
        var newBatches = 0
        if !overflow.isEmpty, let deck = batch.deck {
            newBatches = CardImporter.appendCards(
                overflow.map(normalized), to: deck, in: context
            ).count
        }

        return BulkAppendResult(
            addedToBatch: fitting.count,
            newBatchesCreated: newBatches,
            totalAdded: fitting.count + overflow.count
        )
    }

    /// 把多筆解析結果寫入 deck 末端新建立的批次，不碰任何既有批次。
    /// 批次由 `CardImporter.appendCards` 在寫入內容的同時建立，因此不存在空批次狀態。
    /// - Returns: 寫入統計；`addedToBatch` 恆為 0，因為沒有既有批次被填。空輸入不建立任何批次。
    @discardableResult
    static func appendCardsInNewBatches(
        _ parsed: [ParsedCard],
        to deck: Deck,
        in context: ModelContext
    ) -> BulkAppendResult {
        let valid = parsed.filter { isValid(word: $0.word, translation: $0.translation) }
        guard !valid.isEmpty else {
            return BulkAppendResult(addedToBatch: 0, newBatchesCreated: 0, totalAdded: 0)
        }
        let created = CardImporter.appendCards(valid.map(normalized), to: deck, in: context)
        return BulkAppendResult(
            addedToBatch: 0,
            newBatchesCreated: created.count,
            totalAdded: valid.count
        )
    }

    /// 在批次末端新增一張卡：`importOrder` 接續現有最大值，`wrongCount` 由 0 起算。
    /// - Returns: 建立的卡片；欄位不合法或批次已滿時不建立任何物件並回傳 nil。
    @discardableResult
    static func appendCard(
        to batch: Batch,
        word: String,
        partOfSpeech: String?,
        translation: String,
        in context: ModelContext
    ) -> Card? {
        guard canAppend(to: batch), isValid(word: word, translation: translation) else {
            return nil
        }

        let card = Card(
            word: word,
            partOfSpeech: normalizedOptional(partOfSpeech),
            translation: translation,
            importOrder: (batch.cards.map(\.importOrder).max() ?? -1) + 1
        )
        card.batch = batch
        context.insert(card)
        return card
    }

    /// 更新既有卡片的內容欄位。`wrongCount` 與 `importOrder` 不受影響。
    /// - Returns: 欄位不合法時不寫入任何值並回傳 false。
    @discardableResult
    static func update(
        _ card: Card,
        word: String,
        partOfSpeech: String?,
        translation: String
    ) -> Bool {
        guard isValid(word: word, translation: translation) else { return false }
        card.word = word
        card.partOfSpeech = normalizedOptional(partOfSpeech)
        card.translation = translation
        return true
    }

    /// 刪除一張卡；若批次因此清空，連同批次一併刪除並重新編號其餘批次。
    /// - Returns: 批次是否被移除，供呼叫端決定是否關閉該批次的頁面。
    @discardableResult
    static func deleteCard(_ card: Card, in context: ModelContext) -> Bool {
        // 是否清空必須在刪除「之前」判斷：SwiftData 的關聯陣列不保證在
        // delete 當下同步更新。既有的 PreviewView 多選刪除也是同樣作法。
        let batch = card.batch
        let willEmptyBatch = (batch?.cards.count ?? 0) <= 1
        context.delete(card)

        guard willEmptyBatch, let batch else { return false }
        let deck = batch.deck
        context.delete(batch)
        // 必須先讓 context 處理刪除，`deck.batches` 才不再包含已刪除的批次；
        // 否則 reindexBatches() 會把它一起編號，survivors 拿到錯的 index。
        try? context.save()
        deck?.reindexBatches()
        return true
    }

    /// 把解析結果的詞性正規化，讓經由 `CardImporter` 建立的卡片與直接建立的卡片
    /// 對「留白詞性」有一致的處理。
    private static func normalized(_ parsed: ParsedCard) -> ParsedCard {
        ParsedCard(
            word: parsed.word,
            partOfSpeech: normalizedOptional(parsed.partOfSpeech),
            translation: parsed.translation
        )
    }

    /// 把只含空白（或 nil）的可選字串正規化為 nil，與匯入時「詞性留空視為未提供」一致。
    private static func normalizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
