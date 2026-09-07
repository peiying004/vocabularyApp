import SwiftData
import XCTest
@testable import VocTest

final class ModelTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Task 2.1: Deck-Batch-Card hierarchy and cascade delete

    func testCascadeDeleteRemovesNestedBatchesAndCards() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        // 批次大小取自切批常數，避免建出超過容量上限的批次。
        let batchSizes = [CardImporter.chunkSize, CardImporter.chunkSize, 30]
        for (i, size) in batchSizes.enumerated() {
            let batch = Batch(index: i + 1)
            batch.deck = deck
            ctx.insert(batch)
            for j in 0..<size {
                let card = Card(
                    word: "w\(i)-\(j)",
                    partOfSpeech: nil,
                    translation: "t\(i)-\(j)",
                    importOrder: j
                )
                card.batch = batch
                ctx.insert(card)
            }
        }
        try ctx.save()

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Deck>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Batch>()), 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Card>()), batchSizes.reduce(0, +))

        ctx.delete(deck)
        try ctx.save()

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Deck>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Batch>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Card>()), 0)
    }

    // MARK: - Task 2.2: Card fields + monotonic wrongCount

    func testCardFieldsRoundTripThroughPersistence() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let card = Card(
            word: "apple",
            partOfSpeech: "n.",
            translation: "蘋果",
            importOrder: 12
        )
        for _ in 0..<5 { card.recordWrong() }
        ctx.insert(card)
        try ctx.save()

        let ctx2 = ModelContext(container)
        let fetched = try ctx2.fetch(FetchDescriptor<Card>()).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.word, "apple")
        XCTAssertEqual(fetched?.partOfSpeech, "n.")
        XCTAssertEqual(fetched?.translation, "蘋果")
        XCTAssertEqual(fetched?.wrongCount, 5)
        XCTAssertEqual(fetched?.importOrder, 12)
    }

    func testWrongCountIsMonotonicViaRecordWrong() throws {
        let card = Card(word: "x", partOfSpeech: nil, translation: "y", importOrder: 0)
        XCTAssertEqual(card.wrongCount, 0)

        card.recordWrong()
        card.recordWrong()
        XCTAssertEqual(card.wrongCount, 2)

        card.recordWrong()
        card.recordWrong()
        card.recordWrong()
        XCTAssertEqual(card.wrongCount, 5)

        // API surface contract: wrongCount has `private(set)`, so the following
        // would not compile from outside this module:
        //     card.wrongCount = 0
        //     card.wrongCount -= 1
        // The only mutator is recordWrong(), which only increments.
    }

    // MARK: - Batch-Level Wrong Count Reset: Card.resetWrongCount()

    func testResetWrongCountZeroesTheCount() throws {
        let card = Card(word: "apple", partOfSpeech: "n.", translation: "蘋果", importOrder: 0)
        for _ in 0..<5 { card.recordWrong() }
        XCTAssertEqual(card.wrongCount, 5)

        card.resetWrongCount()

        XCTAssertEqual(card.wrongCount, 0)
    }

    func testWrongCountAccumulatesAgainAfterReset() throws {
        // 規格 Scenario「Wrong counts accumulate again after a reset」。
        let card = Card(word: "apple", partOfSpeech: "n.", translation: "蘋果", importOrder: 0)
        for _ in 0..<3 { card.recordWrong() }
        card.resetWrongCount()

        card.recordWrong()

        XCTAssertEqual(card.wrongCount, 1)
    }

    func testResetWrongCountLeavesContentAndOrderUntouched() throws {
        let card = Card(word: "apple", partOfSpeech: "n.", translation: "蘋果", importOrder: 12)
        card.recordWrong()

        card.resetWrongCount()

        XCTAssertEqual(card.word, "apple")
        XCTAssertEqual(card.partOfSpeech, "n.")
        XCTAssertEqual(card.translation, "蘋果")
        XCTAssertEqual(card.importOrder, 12)
    }

    func testResetIsScopedToTheCardsItIsCalledOn() throws {
        // 規格 Example「only the invoked batch is reset」的模型層對應：
        // 只有被呼叫的卡片歸零，其餘卡片的累計不受影響。
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        let first = Batch(index: 1)
        first.deck = deck
        ctx.insert(first)
        let second = Batch(index: 2)
        second.deck = deck
        ctx.insert(second)

        let inFirst = Card(word: "apple", partOfSpeech: nil, translation: "蘋果", importOrder: 0)
        inFirst.batch = first
        ctx.insert(inFirst)
        for _ in 0..<7 { inFirst.recordWrong() }

        let inSecond = Card(word: "banana", partOfSpeech: nil, translation: "香蕉", importOrder: 0)
        inSecond.batch = second
        ctx.insert(inSecond)
        for _ in 0..<4 { inSecond.recordWrong() }

        for card in first.cards { card.resetWrongCount() }
        try ctx.save()

        XCTAssertEqual(first.cards.reduce(0) { $0 + $1.wrongCount }, 0)
        XCTAssertEqual(second.cards.reduce(0) { $0 + $1.wrongCount }, 4)
    }

    // MARK: - Task 2.3: Batch 1-based index, immutability of cards array

    func testBatchIndicesAreOneBasedAndSequential() throws {
        let b1 = Batch(index: 1)
        let b2 = Batch(index: 2)
        let b3 = Batch(index: 3)
        XCTAssertEqual([b1.index, b2.index, b3.index], [1, 2, 3])
    }

    func testBatchCardsArrayIsNotPubliclyMutable() throws {
        let batch = Batch(index: 1)
        // API surface contract: `cards` is `private(set)`, so the following
        // would not compile from outside the Batch type:
        //     batch.cards = []
        //     batch.cards.append(someCard)
        //     batch.cards.removeAll()
        // The only way to populate a batch's cards is through SwiftData's
        // inverse relationship by setting `card.batch = thisBatch` at
        // insert time, which is what the batching service (task 4.1) does.
        //
        // Note: `index` is intentionally publicly writable so that
        // Deck.reindexBatches() can renumber the surviving batches after a
        // deletion (see add-multi-select-delete / BatchReindexTests).
        XCTAssertEqual(batch.index, 1)
        XCTAssertEqual(batch.cards.count, 0)
    }
}
