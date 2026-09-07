import SwiftData
import XCTest
@testable import VocTest

/// Verifies `Deck.reindexBatches()` and `GrammarDeck.reindexBatches()` against
/// the two Examples in specs/content-deletion/spec.md (Contiguous Batch
/// Renumbering): renumber after deleting a middle batch, and renumber triggered
/// by empty-batch removal. Both must yield a contiguous 1-based sequence that
/// preserves the surviving batches' relative order.
final class BatchReindexTests: XCTestCase {

    // MARK: - Vocabulary side (Deck / Batch / Card)

    private func makeVocabContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Seeds a deck with three batches (index 1, 2, 3), each carrying one marker
    /// card whose word records the batch's original index.
    private func seedVocabDeck(in ctx: ModelContext) -> Deck {
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)
        for i in 1...3 {
            let batch = Batch(index: i)
            batch.deck = deck
            ctx.insert(batch)
            let card = Card(word: "orig\(i)", partOfSpeech: nil, translation: "t", importOrder: 0)
            card.batch = batch
            ctx.insert(card)
        }
        return deck
    }

    private func orderedVocabBatches(_ deck: Deck) -> [Batch] {
        deck.batches.sorted { $0.index < $1.index }
    }

    // Example: renumber after deleting the middle batch.
    func testReindexAfterDeletingMiddleBatch() throws {
        let ctx = ModelContext(try makeVocabContainer())
        let deck = seedVocabDeck(in: ctx)
        try ctx.save()

        let middle = orderedVocabBatches(deck).first { $0.index == 2 }!
        ctx.delete(middle)
        try ctx.save()

        deck.reindexBatches()
        try ctx.save()

        let survivors = orderedVocabBatches(deck)
        XCTAssertEqual(survivors.map(\.index), [1, 2])
        // Index 1 is the original batch 1; index 2 is the original batch 3.
        XCTAssertEqual(survivors[0].cards.first?.word, "orig1")
        XCTAssertEqual(survivors[1].cards.first?.word, "orig3")
    }

    // Example: renumber triggered by empty-batch removal (delete the last item
    // of the middle batch, then the now-empty batch is removed and survivors
    // renumbered).
    func testReindexAfterEmptyBatchRemoval() throws {
        let ctx = ModelContext(try makeVocabContainer())
        let deck = seedVocabDeck(in: ctx)
        try ctx.save()

        let middle = orderedVocabBatches(deck).first { $0.index == 2 }!
        for card in middle.cards { ctx.delete(card) }
        try ctx.save()

        XCTAssertTrue(middle.cards.isEmpty)
        ctx.delete(middle)
        try ctx.save()

        deck.reindexBatches()
        try ctx.save()

        let survivors = orderedVocabBatches(deck)
        XCTAssertEqual(survivors.map(\.index), [1, 2])
        XCTAssertEqual(survivors[0].cards.first?.word, "orig1")
        XCTAssertEqual(survivors[1].cards.first?.word, "orig3")
    }

    // MARK: - Grammar side (GrammarDeck / GrammarBatch / GrammarItem)

    private func makeGrammarContainer() throws -> ModelContainer {
        let schema = Schema([GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func seedGrammarDeck(in ctx: ModelContext) -> GrammarDeck {
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        for i in 1...3 {
            let batch = GrammarBatch(index: i)
            batch.deck = deck
            ctx.insert(batch)
            let item = GrammarItem(
                question: "orig\(i)",
                correct: "A",
                distractors: ["B", "C", "D"],
                explanation: nil,
                importOrder: 0
            )
            item.batch = batch
            ctx.insert(item)
        }
        return deck
    }

    private func orderedGrammarBatches(_ deck: GrammarDeck) -> [GrammarBatch] {
        deck.grammarBatches.sorted { $0.index < $1.index }
    }

    func testGrammarReindexAfterDeletingMiddleBatch() throws {
        let ctx = ModelContext(try makeGrammarContainer())
        let deck = seedGrammarDeck(in: ctx)
        try ctx.save()

        let middle = orderedGrammarBatches(deck).first { $0.index == 2 }!
        ctx.delete(middle)
        try ctx.save()

        deck.reindexBatches()
        try ctx.save()

        let survivors = orderedGrammarBatches(deck)
        XCTAssertEqual(survivors.map(\.index), [1, 2])
        XCTAssertEqual(survivors[0].items.first?.question, "orig1")
        XCTAssertEqual(survivors[1].items.first?.question, "orig3")
    }

    func testGrammarReindexAfterEmptyBatchRemoval() throws {
        let ctx = ModelContext(try makeGrammarContainer())
        let deck = seedGrammarDeck(in: ctx)
        try ctx.save()

        let middle = orderedGrammarBatches(deck).first { $0.index == 2 }!
        for item in middle.items { ctx.delete(item) }
        try ctx.save()

        XCTAssertTrue(middle.items.isEmpty)
        ctx.delete(middle)
        try ctx.save()

        deck.reindexBatches()
        try ctx.save()

        let survivors = orderedGrammarBatches(deck)
        XCTAssertEqual(survivors.map(\.index), [1, 2])
        XCTAssertEqual(survivors[0].items.first?.question, "orig1")
        XCTAssertEqual(survivors[1].items.first?.question, "orig3")
    }
}
