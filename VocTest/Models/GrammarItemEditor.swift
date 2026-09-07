import Foundation
import SwiftData

/// 對既有 `GrammarBatch` 內的文法題做「驗證／新增／刪除」的資料層邏輯。
/// 與 `CardEditor` 對稱，差別只在欄位規則；批次容量兩側同值。純資料層，不涉及 UI。
enum GrammarItemEditor {

    /// 單一批次可容納的題目上限。沿用匯入的切批數量，
    /// 使匯入的切批題數對手動新增同樣是硬上限。
    static var capacity: Int { GrammarItemImporter.chunkSize }

    /// 測驗以「正解 + 干擾選項」組成四個選項，因此干擾選項固定為 3 個。
    static let distractorCount = 3

    /// 驗證題目欄位是否可儲存，規則與 `GrammarMarkdownParser` 的必填規則一致：
    /// 題目與正解去除前後空白後必須非空；干擾選項恰為 3 個且每個皆非空；詳解可省略。
    static func isValid(question: String, correct: String, distractors: [String]) -> Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && !correct.trimmingCharacters(in: .whitespaces).isEmpty
            && distractors.count == distractorCount
            && distractors.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// 該批次是否還能再新增一題（未達 `capacity`）。
    static func canAppend(to batch: GrammarBatch) -> Bool {
        batch.items.count < capacity
    }

    /// 該批次還能再放幾題。已滿時為 0，不會是負數。
    static func remainingCapacity(of batch: GrammarBatch) -> Int {
        Swift.max(0, capacity - batch.items.count)
    }

    /// 批量寫入的結果統計。
    struct BulkAppendResult: Equatable {
        /// 寫進目標批次的題數。
        let addedToBatch: Int
        /// 因溢出而新建立的批次數。
        let newBatchesCreated: Int
        /// 本次總共寫入的題數。
        let totalAdded: Int
    }

    /// 把多筆解析結果寫入既有批次：先填滿目標批次，其餘視 `allowingOverflow` 決定去留。
    /// 溢出的部分交給 `GrammarItemImporter.appendItems`，因此切批與編號規則與匯入完全一致。
    /// - Parameter allowingOverflow: 為 false 且內容超過剩餘容量時，不寫入任何一筆並回傳 nil。
    /// - Returns: 寫入統計；被拒絕時為 nil。
    @discardableResult
    static func appendItems(
        _ parsed: [ParsedGrammarItem],
        to batch: GrammarBatch,
        allowingOverflow: Bool,
        in context: ModelContext
    ) -> BulkAppendResult? {
        // 防禦性過濾：正常情況下解析器已保證通過，但批量路徑不該比單筆路徑寬鬆。
        let valid = parsed.filter {
            isValid(question: $0.question, correct: $0.correct, distractors: $0.distractors)
        }
        let room = remainingCapacity(of: batch)

        // 會不會溢出、能不能溢出，都在寫入任何一筆之前判斷完畢，
        // 避免出現「填了一半才發現放不下」的部分寫入狀態。
        if valid.count > room {
            guard allowingOverflow, batch.deck != nil else { return nil }
        }

        let fitting = Array(valid.prefix(room))
        var nextOrder = (batch.items.map(\.importOrder).max() ?? -1) + 1
        for p in fitting {
            let item = GrammarItem(
                question: p.question,
                correct: p.correct,
                distractors: p.distractors,
                explanation: normalizedOptional(p.explanation),
                importOrder: nextOrder
            )
            item.batch = batch
            context.insert(item)
            nextOrder += 1
        }

        let overflow = Array(valid.dropFirst(room))
        var newBatches = 0
        if !overflow.isEmpty, let deck = batch.deck {
            newBatches = GrammarItemImporter.appendItems(
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
    /// 批次由 `GrammarItemImporter.appendItems` 在寫入內容的同時建立，因此不存在空批次狀態。
    /// - Returns: 寫入統計；`addedToBatch` 恆為 0。空輸入不建立任何批次。
    @discardableResult
    static func appendItemsInNewBatches(
        _ parsed: [ParsedGrammarItem],
        to deck: GrammarDeck,
        in context: ModelContext
    ) -> BulkAppendResult {
        let valid = parsed.filter {
            isValid(question: $0.question, correct: $0.correct, distractors: $0.distractors)
        }
        guard !valid.isEmpty else {
            return BulkAppendResult(addedToBatch: 0, newBatchesCreated: 0, totalAdded: 0)
        }
        let created = GrammarItemImporter.appendItems(valid.map(normalized), to: deck, in: context)
        return BulkAppendResult(
            addedToBatch: 0,
            newBatchesCreated: created.count,
            totalAdded: valid.count
        )
    }

    /// 在批次末端新增一題：`importOrder` 接續現有最大值，`wrongCount` 由 0 起算。
    /// - Returns: 建立的題目；欄位不合法或批次已滿時不建立任何物件並回傳 nil。
    @discardableResult
    static func appendItem(
        to batch: GrammarBatch,
        question: String,
        correct: String,
        distractors: [String],
        explanation: String?,
        in context: ModelContext
    ) -> GrammarItem? {
        guard canAppend(to: batch),
              isValid(question: question, correct: correct, distractors: distractors) else {
            return nil
        }

        let item = GrammarItem(
            question: question,
            correct: correct,
            distractors: distractors,
            explanation: normalizedOptional(explanation),
            importOrder: (batch.items.map(\.importOrder).max() ?? -1) + 1
        )
        item.batch = batch
        context.insert(item)
        return item
    }

    /// 更新既有題目的內容欄位。`wrongCount` 與 `importOrder` 不受影響。
    /// - Returns: 欄位不合法時不寫入任何值並回傳 false。
    @discardableResult
    static func update(
        _ item: GrammarItem,
        question: String,
        correct: String,
        distractors: [String],
        explanation: String?
    ) -> Bool {
        guard isValid(question: question, correct: correct, distractors: distractors) else {
            return false
        }
        item.question = question
        item.correct = correct
        item.distractors = distractors
        item.explanation = normalizedOptional(explanation)
        return true
    }

    /// 刪除一題；若批次因此清空，連同批次一併刪除並重新編號其餘批次。
    /// - Returns: 批次是否被移除，供呼叫端決定是否關閉該批次的頁面。
    @discardableResult
    static func deleteItem(_ item: GrammarItem, in context: ModelContext) -> Bool {
        // 是否清空必須在刪除「之前」判斷：SwiftData 的關聯陣列不保證在
        // delete 當下同步更新。既有的 GrammarPreviewView 多選刪除也是同樣作法。
        let batch = item.batch
        let willEmptyBatch = (batch?.items.count ?? 0) <= 1
        context.delete(item)

        guard willEmptyBatch, let batch else { return false }
        let deck = batch.deck
        context.delete(batch)
        // 必須先讓 context 處理刪除，`deck.grammarBatches` 才不再包含已刪除的批次；
        // 否則 reindexBatches() 會把它一起編號，survivors 拿到錯的 index。
        try? context.save()
        deck?.reindexBatches()
        return true
    }

    /// 把解析結果的詳解正規化，讓經由 `GrammarItemImporter` 建立的題目與直接建立的題目
    /// 對「留白詳解」有一致的處理。
    private static func normalized(_ parsed: ParsedGrammarItem) -> ParsedGrammarItem {
        ParsedGrammarItem(
            question: parsed.question,
            correct: parsed.correct,
            distractors: parsed.distractors,
            explanation: normalizedOptional(parsed.explanation)
        )
    }

    /// 把只含空白（或 nil）的可選字串正規化為 nil，與匯入時「詳解留空視為未提供」一致。
    private static func normalizedOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
