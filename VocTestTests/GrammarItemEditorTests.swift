import SwiftData
import XCTest
@testable import VocTest

/// 覆蓋 `GrammarItemEditor` 的驗證、新增、更新、刪除行為，與 `CardEditorTests` 對稱。
/// 測試值取自 content-editing 規格的 `##### Example:` 區塊。
final class GrammarItemEditorTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// 建立一個掛在 deck 底下的批次，並依序填入 `itemCount` 道題目。
    @discardableResult
    private func makeBatch(
        index: Int,
        itemCount: Int,
        in deck: GrammarDeck,
        context: ModelContext
    ) -> GrammarBatch {
        let batch = GrammarBatch(index: index)
        batch.deck = deck
        context.insert(batch)
        for j in 0..<itemCount {
            let item = GrammarItem(
                question: "q\(index)-\(j)",
                correct: "A",
                distractors: ["B", "C", "D"],
                explanation: nil,
                importOrder: j
            )
            item.batch = batch
            context.insert(item)
        }
        return batch
    }

    // MARK: - Edit Validation Matches Import Rules / Fixed Distractor Count

    func testGrammarFieldValidationMatchesSpecExamples() {
        // 規格 Example「grammar item field validation」的五列。
        XCTAssertTrue(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "goes", distractors: ["go", "going", "gone"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "goes", distractors: ["go", "going"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "goes", distractors: ["go", "", "gone"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "", correct: "goes", distractors: ["go", "going", "gone"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "", distractors: ["go", "going", "gone"]
        ))
    }

    func testDistractorCountMustBeExactlyThree() {
        let question = "He ___ there."
        let correct = "goes"

        XCTAssertFalse(GrammarItemEditor.isValid(
            question: question, correct: correct, distractors: []
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: question, correct: correct, distractors: ["go", "going"]
        ))
        XCTAssertTrue(GrammarItemEditor.isValid(
            question: question, correct: correct, distractors: ["go", "going", "gone"]
        ))
        XCTAssertFalse(
            GrammarItemEditor.isValid(
                question: question,
                correct: correct,
                distractors: ["go", "going", "gone", "went"]
            ),
            "多於 3 個干擾選項會讓測驗選項數超過四個，必須被拒絕"
        )
        XCTAssertEqual(GrammarItemEditor.distractorCount, 3)
    }

    func testWhitespaceOnlyFieldsAreInvalid() {
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "   ", correct: "goes", distractors: ["go", "going", "gone"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "  ", distractors: ["go", "going", "gone"]
        ))
        XCTAssertFalse(GrammarItemEditor.isValid(
            question: "He ___ there.", correct: "goes", distractors: ["go", "  ", "gone"]
        ))
    }

    func testEmptyExplanationIsStoredAsNil() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 0, in: deck, context: ctx)

        let withExplanation = GrammarItemEditor.appendItem(
            to: batch, question: "q1", correct: "A",
            distractors: ["B", "C", "D"], explanation: "因為現在式", in: ctx
        )
        let withoutExplanation = GrammarItemEditor.appendItem(
            to: batch, question: "q2", correct: "A",
            distractors: ["B", "C", "D"], explanation: "", in: ctx
        )
        let whitespaceExplanation = GrammarItemEditor.appendItem(
            to: batch, question: "q3", correct: "A",
            distractors: ["B", "C", "D"], explanation: "   ", in: ctx
        )

        XCTAssertEqual(withExplanation?.explanation, "因為現在式")
        XCTAssertNil(withoutExplanation?.explanation)
        XCTAssertNil(whitespaceExplanation?.explanation)
    }

    func testAppendRejectsInvalidFields() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 3, in: deck, context: ctx)

        let created = GrammarItemEditor.appendItem(
            to: batch, question: "q", correct: "A",
            distractors: ["B", "C"], explanation: nil, in: ctx
        )

        XCTAssertNil(created)
        XCTAssertEqual(batch.items.count, 3)
    }

    // MARK: - Single Item Creation Within A Batch

    func testAppendAssignsNextImportOrderAndZeroWrongCount() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 3, in: deck, context: ctx)

        let created = GrammarItemEditor.appendItem(
            to: batch, question: "new", correct: "A",
            distractors: ["B", "C", "D"], explanation: nil, in: ctx
        )

        XCTAssertEqual(created?.importOrder, 3)
        XCTAssertEqual(created?.wrongCount, 0)
        XCTAssertEqual(
            batch.items.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 2, 3]
        )
    }

    func testAppendIntoEmptyBatchStartsAtZero() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 0, in: deck, context: ctx)

        let created = GrammarItemEditor.appendItem(
            to: batch, question: "q", correct: "A",
            distractors: ["B", "C", "D"], explanation: nil, in: ctx
        )

        XCTAssertEqual(created?.importOrder, 0)
    }

    // MARK: - Batch Capacity Invariant

    func testCapacityMatchesImportChunkSize() {
        XCTAssertEqual(GrammarItemEditor.capacity, GrammarItemImporter.chunkSize)
        XCTAssertEqual(GrammarItemEditor.capacity, CardEditor.capacity, "兩側容量刻意同值")
    }

    func testCanAppendAtCapacityBoundaries() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        let empty = makeBatch(index: 1, itemCount: 0, in: deck, context: ctx)
        let almostFull = makeBatch(index: 2, itemCount: GrammarItemEditor.capacity - 1, in: deck, context: ctx)
        let full = makeBatch(index: 3, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)

        XCTAssertTrue(GrammarItemEditor.canAppend(to: empty))
        XCTAssertTrue(GrammarItemEditor.canAppend(to: almostFull))
        XCTAssertFalse(GrammarItemEditor.canAppend(to: full))
    }

    func testAppendToFullBatchIsRefused() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let full = makeBatch(index: 1, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)

        let created = GrammarItemEditor.appendItem(
            to: full, question: "overflow", correct: "A",
            distractors: ["B", "C", "D"], explanation: nil, in: ctx
        )

        XCTAssertNil(created)
        XCTAssertEqual(full.items.count, GrammarItemEditor.capacity)
        XCTAssertEqual(deck.grammarBatches.count, 1, "新增被拒時不得建立新批次")
    }

    func testFullBatchDoesNotOverflowIntoAnotherBatch() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let first = makeBatch(index: 1, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)
        let second = makeBatch(index: 2, itemCount: 5, in: deck, context: ctx)

        XCTAssertNil(GrammarItemEditor.appendItem(
            to: first, question: "q", correct: "A",
            distractors: ["B", "C", "D"], explanation: nil, in: ctx
        ))
        XCTAssertEqual(first.items.count, GrammarItemEditor.capacity)
        XCTAssertEqual(second.items.count, 5)
    }

    // MARK: - Practice Records And Ordering Preserved On Edit

    func testUpdatePreservesWrongCountAndImportOrder() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 0, in: deck, context: ctx)

        let item = GrammarItem(
            question: "He ___ there.",
            correct: "goes",
            distractors: ["go", "going", "gone"],
            explanation: nil,
            importOrder: 4
        )
        item.batch = batch
        ctx.insert(item)
        for _ in 0..<2 { item.recordWrong() }

        let didUpdate = GrammarItemEditor.update(
            item,
            question: "She ___ there.",
            correct: "goes",
            distractors: ["go", "going", "gone"],
            explanation: "第三人稱單數"
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(item.question, "She ___ there.")
        XCTAssertEqual(item.explanation, "第三人稱單數")
        XCTAssertEqual(item.wrongCount, 2)
        XCTAssertEqual(item.importOrder, 4)
    }

    func testUpdateWithInvalidFieldsWritesNothing() {
        let item = GrammarItem(
            question: "He ___ there.",
            correct: "goes",
            distractors: ["go", "going", "gone"],
            explanation: nil,
            importOrder: 0
        )

        let didUpdate = GrammarItemEditor.update(
            item, question: "He ___ there.", correct: "goes",
            distractors: ["go", "going"], explanation: nil
        )

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(item.distractors, ["go", "going", "gone"])
    }

    // MARK: - Single Item Deletion From The Editing Screen

    func testDeletingOneOfManyKeepsBatchAndOtherImportOrders() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 5, in: deck, context: ctx)
        let target = batch.items.sorted { $0.importOrder < $1.importOrder }[2]

        let batchRemoved = GrammarItemEditor.deleteItem(target, in: ctx)
        try ctx.save()

        XCTAssertFalse(batchRemoved)
        XCTAssertEqual(batch.items.count, 4)
        XCTAssertEqual(
            batch.items.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 3, 4],
            "刪除一題不重新指派其餘題目的 importOrder"
        )
    }

    func testDeletingLastItemRemovesBatchAndRenumbersDeck() throws {
        // 規格 Example「renumbering after deleting the last item of a middle batch」：
        // 批次 1(20)、批次 2(1)、批次 3(15)，刪光批次 2 之後剩下 1 與 2。
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        makeBatch(index: 1, itemCount: 20, in: deck, context: ctx)
        let middle = makeBatch(index: 2, itemCount: 1, in: deck, context: ctx)
        let last = makeBatch(index: 3, itemCount: 15, in: deck, context: ctx)

        let onlyItem = try XCTUnwrap(middle.items.first)
        let batchRemoved = GrammarItemEditor.deleteItem(onlyItem, in: ctx)
        try ctx.save()

        XCTAssertTrue(batchRemoved)
        XCTAssertEqual(deck.grammarBatches.count, 2)
        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2]
        )
        XCTAssertEqual(last.index, 2, "原本的批次 3 重新編號為 2")
        XCTAssertEqual(last.items.count, 15)
    }

    // MARK: - 批量寫入輔助

    private func makeParsed(count: Int, prefix: String = "p") -> [ParsedGrammarItem] {
        (0..<count).map {
            ParsedGrammarItem(
                question: "\(prefix)\($0)",
                correct: "A",
                distractors: ["B", "C", "D"],
                explanation: nil
            )
        }
    }

    // MARK: - Paste Markdown Into An Existing Batch

    func testRemainingCapacityAtBoundaries() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        let empty = makeBatch(index: 1, itemCount: 0, in: deck, context: ctx)
        let almostFull = makeBatch(index: 2, itemCount: GrammarItemEditor.capacity - 1, in: deck, context: ctx)
        let full = makeBatch(index: 3, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)

        XCTAssertEqual(GrammarItemEditor.remainingCapacity(of: empty), GrammarItemEditor.capacity)
        XCTAssertEqual(GrammarItemEditor.remainingCapacity(of: almostFull), 1)
        XCTAssertEqual(GrammarItemEditor.remainingCapacity(of: full), 0)
    }

    func testBulkAppendWithinCapacityFillsBatchOnly() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 32, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItems(
            makeParsed(count: 5), to: batch, allowingOverflow: false, in: ctx
        )

        XCTAssertEqual(result?.addedToBatch, 5)
        XCTAssertEqual(result?.newBatchesCreated, 0)
        XCTAssertEqual(result?.totalAdded, 5)
        XCTAssertEqual(batch.items.count, 37)
        XCTAssertEqual(deck.grammarBatches.count, 1)

        let added = batch.items.filter { $0.question.hasPrefix("p") }
            .sorted { $0.importOrder < $1.importOrder }
        XCTAssertEqual(added.map(\.importOrder), [32, 33, 34, 35, 36])
        XCTAssertTrue(added.allSatisfy { $0.wrongCount == 0 })
    }

    func testBulkAppendLeavesExistingItemsUntouched() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 3, in: deck, context: ctx)
        let existing = batch.items.sorted { $0.importOrder < $1.importOrder }
        existing.forEach { $0.recordWrong() }
        let before = existing.map { ($0.question, $0.correct, $0.wrongCount, $0.importOrder) }

        GrammarItemEditor.appendItems(makeParsed(count: 4), to: batch, allowingOverflow: false, in: ctx)

        let after = batch.items.filter { !$0.question.hasPrefix("p") }
            .sorted { $0.importOrder < $1.importOrder }
            .map { ($0.question, $0.correct, $0.wrongCount, $0.importOrder) }
        XCTAssertEqual(after.map(\.0), before.map(\.0))
        XCTAssertEqual(after.map(\.1), before.map(\.1))
        XCTAssertEqual(after.map(\.2), before.map(\.2))
        XCTAssertEqual(after.map(\.3), before.map(\.3))
    }

    // MARK: - Abandoning An Over-Capacity Paste Writes Nothing

    func testBulkAppendOverCapacityWithoutOverflowWritesNothing() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 32, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItems(
            makeParsed(count: 12), to: batch, allowingOverflow: false, in: ctx
        )

        XCTAssertNil(result)
        XCTAssertEqual(batch.items.count, 32)
        XCTAssertEqual(deck.grammarBatches.count, 1)
    }

    // MARK: - Overflow Fills The Batch Then Creates New Batches

    func testOverflowFillsBatchThenCreatesOneNewBatch() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, itemCount: 32, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItems(
            makeParsed(count: 12), to: batch, allowingOverflow: true, in: ctx
        )
        try ctx.save()

        XCTAssertEqual(result?.addedToBatch, 8)
        XCTAssertEqual(result?.newBatchesCreated, 1)
        XCTAssertEqual(result?.totalAdded, 12)
        XCTAssertEqual(batch.items.count, GrammarItemEditor.capacity)
        XCTAssertEqual(deck.grammarBatches.count, 2)

        let newBatch = deck.grammarBatches.first { $0.index == 2 }
        XCTAssertEqual(newBatch?.items.count, 4)
        XCTAssertEqual(
            newBatch?.items.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 2, 3]
        )
    }

    func testOverflowSpanningSeveralNewBatches() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        makeBatch(index: 1, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)
        let target = makeBatch(index: 2, itemCount: GrammarItemEditor.capacity - 1, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItems(
            makeParsed(count: 83), to: target, allowingOverflow: true, in: ctx
        )
        try ctx.save()

        XCTAssertEqual(result?.addedToBatch, 1)
        XCTAssertEqual(result?.newBatchesCreated, 3)
        XCTAssertEqual(result?.totalAdded, 83)
        XCTAssertEqual(target.items.count, GrammarItemEditor.capacity)
        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.items.count),
            [GrammarItemEditor.capacity, GrammarItemEditor.capacity,
             GrammarItemEditor.capacity, GrammarItemEditor.capacity, 2]
        )
        XCTAssertTrue(deck.grammarBatches.allSatisfy { $0.items.count <= GrammarItemEditor.capacity })
    }

    // MARK: - Paste With A Deck Target Writes Only New Batches

    func testAppendInNewBatchesWithSingleItem() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let full = makeBatch(index: 1, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItemsInNewBatches(makeParsed(count: 1), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(result.addedToBatch, 0)
        XCTAssertEqual(result.newBatchesCreated, 1)
        XCTAssertEqual(result.totalAdded, 1)
        XCTAssertEqual(full.items.count, GrammarItemEditor.capacity, "既有的滿批次不得被動到")

        let created = deck.grammarBatches.first { $0.index == 2 }
        XCTAssertEqual(created?.items.count, 1)
        XCTAssertEqual(created?.items.first?.importOrder, 0)
    }

    func testAppendInNewBatchesSpanningSeveralBatches() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        makeBatch(index: 1, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)
        makeBatch(index: 2, itemCount: GrammarItemEditor.capacity, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItemsInNewBatches(makeParsed(count: 83), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(result.newBatchesCreated, 3)
        XCTAssertEqual(result.totalAdded, 83)
        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.items.count),
            [GrammarItemEditor.capacity, GrammarItemEditor.capacity,
             GrammarItemEditor.capacity, GrammarItemEditor.capacity, 3]
        )
    }

    func testAppendInNewBatchesWithNoValidItemsCreatesNothing() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        makeBatch(index: 1, itemCount: 5, in: deck, context: ctx)

        let result = GrammarItemEditor.appendItemsInNewBatches([], to: deck, in: ctx)

        XCTAssertEqual(result.newBatchesCreated, 0)
        XCTAssertEqual(result.totalAdded, 0)
        XCTAssertEqual(deck.grammarBatches.count, 1)
    }
}
