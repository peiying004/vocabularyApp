import SwiftData
import XCTest
@testable import VocTest

/// 覆蓋 `CardEditor` 的驗證、新增、更新、刪除行為。
/// 測試值取自 content-editing 規格的 `##### Example:` 區塊。
final class CardEditorTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// 建立一個掛在 deck 底下的批次，並依序填入 `count` 張卡。
    @discardableResult
    private func makeBatch(
        index: Int,
        cardCount: Int,
        in deck: Deck,
        context: ModelContext
    ) -> Batch {
        let batch = Batch(index: index)
        batch.deck = deck
        context.insert(batch)
        for j in 0..<cardCount {
            let card = Card(
                word: "w\(index)-\(j)",
                partOfSpeech: nil,
                translation: "t\(index)-\(j)",
                importOrder: j
            )
            card.batch = batch
            context.insert(card)
        }
        return batch
    }

    // MARK: - Edit Validation Matches Import Rules

    func testCardFieldValidationMatchesSpecExamples() {
        // 規格 Example「card field validation」的五列。
        XCTAssertTrue(CardEditor.isValid(word: "apple", translation: "蘋果"))
        XCTAssertTrue(CardEditor.isValid(word: "apple", translation: "蘋果"))
        XCTAssertFalse(CardEditor.isValid(word: "", translation: "蘋果"))
        XCTAssertFalse(CardEditor.isValid(word: "apple", translation: ""))
        XCTAssertFalse(CardEditor.isValid(word: "   ", translation: "蘋果"))
    }

    func testWhitespaceOnlyTranslationIsInvalid() {
        XCTAssertFalse(CardEditor.isValid(word: "apple", translation: "   "))
    }

    func testEmptyPartOfSpeechIsStoredAsNil() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 0, in: deck, context: ctx)

        let withPOS = CardEditor.appendCard(
            to: batch, word: "apple", partOfSpeech: "n.", translation: "蘋果", in: ctx
        )
        let withoutPOS = CardEditor.appendCard(
            to: batch, word: "banana", partOfSpeech: "", translation: "香蕉", in: ctx
        )
        let whitespacePOS = CardEditor.appendCard(
            to: batch, word: "cherry", partOfSpeech: "  ", translation: "櫻桃", in: ctx
        )

        XCTAssertEqual(withPOS?.partOfSpeech, "n.")
        XCTAssertNil(withoutPOS?.partOfSpeech)
        XCTAssertNil(whitespacePOS?.partOfSpeech)
    }

    func testAppendRejectsInvalidFields() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 3, in: deck, context: ctx)

        let created = CardEditor.appendCard(
            to: batch, word: "  ", partOfSpeech: nil, translation: "蘋果", in: ctx
        )

        XCTAssertNil(created)
        XCTAssertEqual(batch.cards.count, 3)
    }

    // MARK: - Single Item Creation Within A Batch

    func testAppendAssignsNextImportOrderAndZeroWrongCount() throws {
        // 規格 Example「importOrder assigned on creation」：既有 0,1,2 → 新卡為 3。
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 3, in: deck, context: ctx)

        let created = CardEditor.appendCard(
            to: batch, word: "date", partOfSpeech: nil, translation: "棗子", in: ctx
        )

        XCTAssertEqual(created?.importOrder, 3)
        XCTAssertEqual(created?.wrongCount, 0)
        XCTAssertEqual(batch.cards.count, 4)
        XCTAssertEqual(
            batch.cards.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 2, 3]
        )
    }

    func testAppendIntoEmptyBatchStartsAtZero() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 0, in: deck, context: ctx)

        let created = CardEditor.appendCard(
            to: batch, word: "apple", partOfSpeech: nil, translation: "蘋果", in: ctx
        )

        XCTAssertEqual(created?.importOrder, 0)
    }

    // MARK: - Batch Capacity Invariant

    func testCapacityMatchesImportChunkSize() {
        XCTAssertEqual(CardEditor.capacity, CardImporter.chunkSize)
        XCTAssertEqual(CardEditor.capacity, GrammarItemEditor.capacity, "兩側容量刻意同值")
    }

    func testCanAppendAtCapacityBoundaries() throws {
        // 規格 Example「capacity boundary behavior」：0 與 capacity-1 可新增，capacity 不可。
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        let empty = makeBatch(index: 1, cardCount: 0, in: deck, context: ctx)
        let almostFull = makeBatch(index: 2, cardCount: CardEditor.capacity - 1, in: deck, context: ctx)
        let full = makeBatch(index: 3, cardCount: CardEditor.capacity, in: deck, context: ctx)

        XCTAssertTrue(CardEditor.canAppend(to: empty))
        XCTAssertTrue(CardEditor.canAppend(to: almostFull))
        XCTAssertFalse(CardEditor.canAppend(to: full))
    }

    func testAppendToFullBatchIsRefused() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let full = makeBatch(index: 1, cardCount: CardEditor.capacity, in: deck, context: ctx)

        let created = CardEditor.appendCard(
            to: full, word: "overflow", partOfSpeech: nil, translation: "溢位", in: ctx
        )

        XCTAssertNil(created)
        XCTAssertEqual(full.cards.count, CardEditor.capacity)
        XCTAssertEqual(deck.batches.count, 1, "新增被拒時不得建立新批次")
    }

    func testFullBatchDoesNotOverflowIntoAnotherBatch() throws {
        // 規格 Scenario「A full batch does not overflow into another batch」。
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let first = makeBatch(index: 1, cardCount: CardEditor.capacity, in: deck, context: ctx)
        let second = makeBatch(index: 2, cardCount: 10, in: deck, context: ctx)

        XCTAssertNil(CardEditor.appendCard(
            to: first, word: "x", partOfSpeech: nil, translation: "y", in: ctx
        ))
        XCTAssertEqual(first.cards.count, CardEditor.capacity)
        XCTAssertEqual(second.cards.count, 10)
    }

    // MARK: - Practice Records And Ordering Preserved On Edit

    func testUpdatePreservesWrongCountAndImportOrder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 0, in: deck, context: ctx)

        let card = Card(word: "apple", partOfSpeech: "n.", translation: "蘋果", importOrder: 7)
        card.batch = batch
        ctx.insert(card)
        for _ in 0..<3 { card.recordWrong() }

        let didUpdate = CardEditor.update(
            card, word: "apple", partOfSpeech: "n.", translation: "青蘋果"
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(card.translation, "青蘋果")
        XCTAssertEqual(card.wrongCount, 3)
        XCTAssertEqual(card.importOrder, 7)
    }

    func testUpdateWithInvalidFieldsWritesNothing() throws {
        let card = Card(word: "apple", partOfSpeech: "n.", translation: "蘋果", importOrder: 0)

        let didUpdate = CardEditor.update(card, word: "apple", partOfSpeech: "adj.", translation: "")

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(card.word, "apple")
        XCTAssertEqual(card.partOfSpeech, "n.")
        XCTAssertEqual(card.translation, "蘋果")
    }

    // MARK: - Single Item Deletion From The Editing Screen

    func testDeletingOneOfManyKeepsBatchAndOtherImportOrders() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 5, in: deck, context: ctx)
        let sorted = batch.cards.sorted { $0.importOrder < $1.importOrder }
        let target = sorted[2]

        let batchRemoved = CardEditor.deleteCard(target, in: ctx)
        try ctx.save()

        XCTAssertFalse(batchRemoved)
        XCTAssertEqual(batch.cards.count, 4)
        XCTAssertEqual(
            batch.cards.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 3, 4],
            "刪除一張卡不重新指派其餘卡片的 importOrder"
        )
    }

    func testDeletingLastCardRemovesBatchAndRenumbersDeck() throws {
        // 規格 Example「renumbering after deleting the last item of a middle batch」的單字版：
        // 批次 1(20)、批次 2(1)、批次 3(15)，刪光批次 2 之後剩下 1 與 2。
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        makeBatch(index: 1, cardCount: 20, in: deck, context: ctx)
        let middle = makeBatch(index: 2, cardCount: 1, in: deck, context: ctx)
        let last = makeBatch(index: 3, cardCount: 15, in: deck, context: ctx)

        let onlyCard = try XCTUnwrap(middle.cards.first)
        let batchRemoved = CardEditor.deleteCard(onlyCard, in: ctx)
        try ctx.save()

        XCTAssertTrue(batchRemoved)
        XCTAssertEqual(deck.batches.count, 2)
        XCTAssertEqual(deck.batches.sorted { $0.index < $1.index }.map(\.index), [1, 2])
        XCTAssertEqual(last.index, 2, "原本的批次 3 重新編號為 2")
        XCTAssertEqual(last.cards.count, 15)
    }

    // MARK: - 批量寫入輔助

    private func makeParsed(count: Int, prefix: String = "p") -> [ParsedCard] {
        (0..<count).map {
            ParsedCard(word: "\(prefix)\($0)", partOfSpeech: "n.", translation: "t-\(prefix)\($0)")
        }
    }

    // MARK: - Paste Markdown Into An Existing Batch

    func testRemainingCapacityAtBoundaries() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        let empty = makeBatch(index: 1, cardCount: 0, in: deck, context: ctx)
        let almostFull = makeBatch(index: 2, cardCount: CardEditor.capacity - 1, in: deck, context: ctx)
        let full = makeBatch(index: 3, cardCount: CardEditor.capacity, in: deck, context: ctx)

        XCTAssertEqual(CardEditor.remainingCapacity(of: empty), CardEditor.capacity)
        XCTAssertEqual(CardEditor.remainingCapacity(of: almostFull), 1)
        XCTAssertEqual(CardEditor.remainingCapacity(of: full), 0)
    }

    func testBulkAppendWithinCapacityFillsBatchOnly() throws {
        // 規格 Example「importOrder continues from the batch maximum」：32 筆 + 5 筆 → 32…36。
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 32, in: deck, context: ctx)

        let result = CardEditor.appendCards(
            makeParsed(count: 5), to: batch, allowingOverflow: false, in: ctx
        )

        XCTAssertEqual(result?.addedToBatch, 5)
        XCTAssertEqual(result?.newBatchesCreated, 0)
        XCTAssertEqual(result?.totalAdded, 5)
        XCTAssertEqual(batch.cards.count, 37)
        XCTAssertEqual(deck.batches.count, 1)

        let added = batch.cards.filter { $0.word.hasPrefix("p") }
            .sorted { $0.importOrder < $1.importOrder }
        XCTAssertEqual(added.map(\.importOrder), [32, 33, 34, 35, 36])
        XCTAssertTrue(added.allSatisfy { $0.wrongCount == 0 })
    }

    func testBulkAppendLeavesExistingItemsUntouched() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 3, in: deck, context: ctx)
        let existing = batch.cards.sorted { $0.importOrder < $1.importOrder }
        existing.forEach { $0.recordWrong() }
        let before = existing.map { ($0.word, $0.translation, $0.wrongCount, $0.importOrder) }

        CardEditor.appendCards(makeParsed(count: 4), to: batch, allowingOverflow: false, in: ctx)

        let after = batch.cards.filter { !$0.word.hasPrefix("p") }
            .sorted { $0.importOrder < $1.importOrder }
            .map { ($0.word, $0.translation, $0.wrongCount, $0.importOrder) }
        XCTAssertEqual(after.map(\.0), before.map(\.0))
        XCTAssertEqual(after.map(\.1), before.map(\.1))
        XCTAssertEqual(after.map(\.2), before.map(\.2))
        XCTAssertEqual(after.map(\.3), before.map(\.3))
    }

    // MARK: - Abandoning An Over-Capacity Paste Writes Nothing

    func testBulkAppendOverCapacityWithoutOverflowWritesNothing() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 32, in: deck, context: ctx)

        let result = CardEditor.appendCards(
            makeParsed(count: 12), to: batch, allowingOverflow: false, in: ctx
        )

        XCTAssertNil(result)
        XCTAssertEqual(batch.cards.count, 32)
        XCTAssertEqual(deck.batches.count, 1)
    }

    // MARK: - Overflow Fills The Batch Then Creates New Batches

    func testOverflowFillsBatchThenCreatesOneNewBatch() throws {
        // 規格 Scenario：32 筆的批次寫入 12 筆 → 目標批次滿 40，新批次 4 筆。
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let batch = makeBatch(index: 1, cardCount: 32, in: deck, context: ctx)

        let result = CardEditor.appendCards(
            makeParsed(count: 12), to: batch, allowingOverflow: true, in: ctx
        )
        try ctx.save()

        XCTAssertEqual(result?.addedToBatch, 8)
        XCTAssertEqual(result?.newBatchesCreated, 1)
        XCTAssertEqual(result?.totalAdded, 12)
        XCTAssertEqual(batch.cards.count, CardEditor.capacity)
        XCTAssertEqual(deck.batches.count, 2)

        let newBatch = deck.batches.first { $0.index == 2 }
        XCTAssertEqual(newBatch?.cards.count, 4)
        XCTAssertEqual(
            newBatch?.cards.sorted { $0.importOrder < $1.importOrder }.map(\.importOrder),
            [0, 1, 2, 3]
        )
    }

    func testOverflowSpanningSeveralNewBatches() throws {
        // 規格 Example：39 筆的批次寫入 83 筆 → 目標滿 40，其餘 82 筆切成 40、40、2。
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        makeBatch(index: 1, cardCount: CardEditor.capacity, in: deck, context: ctx)
        let target = makeBatch(index: 2, cardCount: CardEditor.capacity - 1, in: deck, context: ctx)

        let result = CardEditor.appendCards(
            makeParsed(count: 83), to: target, allowingOverflow: true, in: ctx
        )
        try ctx.save()

        XCTAssertEqual(result?.addedToBatch, 1)
        XCTAssertEqual(result?.newBatchesCreated, 3)
        XCTAssertEqual(result?.totalAdded, 83)
        XCTAssertEqual(target.cards.count, CardEditor.capacity)
        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.cards.count),
            [CardEditor.capacity, CardEditor.capacity, CardEditor.capacity, CardEditor.capacity, 2]
        )
        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2, 3, 4, 5]
        )
        XCTAssertTrue(deck.batches.allSatisfy { $0.cards.count <= CardEditor.capacity })
    }

    // MARK: - Paste With A Deck Target Writes Only New Batches

    func testAppendInNewBatchesWithSingleItem() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        let full = makeBatch(index: 1, cardCount: CardEditor.capacity, in: deck, context: ctx)

        let result = CardEditor.appendCardsInNewBatches(makeParsed(count: 1), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(result.addedToBatch, 0)
        XCTAssertEqual(result.newBatchesCreated, 1)
        XCTAssertEqual(result.totalAdded, 1)
        XCTAssertEqual(full.cards.count, CardEditor.capacity, "既有的滿批次不得被動到")

        let created = deck.batches.first { $0.index == 2 }
        XCTAssertEqual(created?.cards.count, 1)
        XCTAssertEqual(created?.cards.first?.importOrder, 0)
    }

    func testAppendInNewBatchesSpanningSeveralBatches() throws {
        // 規格 Example：deck 已有兩個滿批次，貼 83 筆 → 新增 40、40、3。
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        makeBatch(index: 1, cardCount: CardEditor.capacity, in: deck, context: ctx)
        makeBatch(index: 2, cardCount: CardEditor.capacity, in: deck, context: ctx)

        let result = CardEditor.appendCardsInNewBatches(makeParsed(count: 83), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(result.newBatchesCreated, 3)
        XCTAssertEqual(result.totalAdded, 83)
        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.cards.count),
            [CardEditor.capacity, CardEditor.capacity, CardEditor.capacity, CardEditor.capacity, 3]
        )
        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2, 3, 4, 5]
        )
    }

    func testAppendInNewBatchesWithNoValidItemsCreatesNothing() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        makeBatch(index: 1, cardCount: 5, in: deck, context: ctx)

        let result = CardEditor.appendCardsInNewBatches([], to: deck, in: ctx)

        XCTAssertEqual(result.newBatchesCreated, 0)
        XCTAssertEqual(result.totalAdded, 0)
        XCTAssertEqual(deck.batches.count, 1)
    }
}
