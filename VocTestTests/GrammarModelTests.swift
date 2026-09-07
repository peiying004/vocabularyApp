import SwiftData
import XCTest
@testable import VocTest

final class GrammarModelTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Batch-Level Wrong Count Reset: GrammarItem.resetWrongCount()

    private func makeItem(question: String = "He ___ there.") -> GrammarItem {
        GrammarItem(
            question: question,
            correct: "goes",
            distractors: ["go", "going", "gone"],
            explanation: "第三人稱單數",
            importOrder: 5
        )
    }

    func testResetWrongCountZeroesTheCount() throws {
        let item = makeItem()
        for _ in 0..<4 { item.recordWrong() }
        XCTAssertEqual(item.wrongCount, 4)

        item.resetWrongCount()

        XCTAssertEqual(item.wrongCount, 0)
    }

    func testWrongCountAccumulatesAgainAfterReset() throws {
        let item = makeItem()
        for _ in 0..<3 { item.recordWrong() }
        item.resetWrongCount()

        item.recordWrong()

        XCTAssertEqual(item.wrongCount, 1)
    }

    func testResetWrongCountLeavesContentAndOrderUntouched() throws {
        let item = makeItem()
        item.recordWrong()

        item.resetWrongCount()

        XCTAssertEqual(item.question, "He ___ there.")
        XCTAssertEqual(item.correct, "goes")
        XCTAssertEqual(item.distractors, ["go", "going", "gone"])
        XCTAssertEqual(item.explanation, "第三人稱單數")
        XCTAssertEqual(item.importOrder, 5)
    }

    func testResetIsScopedToTheItemsItIsCalledOn() throws {
        let ctx = ModelContext(try makeContainer())
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        let first = GrammarBatch(index: 1)
        first.deck = deck
        ctx.insert(first)
        let second = GrammarBatch(index: 2)
        second.deck = deck
        ctx.insert(second)

        let inFirst = makeItem(question: "q1")
        inFirst.batch = first
        ctx.insert(inFirst)
        for _ in 0..<6 { inFirst.recordWrong() }

        let inSecond = makeItem(question: "q2")
        inSecond.batch = second
        ctx.insert(inSecond)
        for _ in 0..<2 { inSecond.recordWrong() }

        for item in first.items { item.resetWrongCount() }
        try ctx.save()

        XCTAssertEqual(first.items.reduce(0) { $0 + $1.wrongCount }, 0)
        XCTAssertEqual(second.items.reduce(0) { $0 + $1.wrongCount }, 2)
    }

    func testGrammarItemFieldsRoundTrip() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = GrammarBatch(index: 1)
        batch.deck = deck
        ctx.insert(batch)
        let item = GrammarItem(
            question: "I ___ to school every day.",
            correct: "go",
            distractors: ["goes", "going", "gone"],
            explanation: "主詞 I 用動詞原形",
            importOrder: 7
        )
        item.batch = batch
        ctx.insert(item)
        item.recordWrong()
        item.recordWrong()
        item.recordWrong()
        item.recordWrong()
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<GrammarItem>()).first!
        XCTAssertEqual(fetched.question, "I ___ to school every day.")
        XCTAssertEqual(fetched.correct, "go")
        XCTAssertEqual(fetched.distractors, ["goes", "going", "gone"])
        XCTAssertEqual(fetched.explanation, "主詞 I 用動詞原形")
        XCTAssertEqual(fetched.wrongCount, 4)
        XCTAssertEqual(fetched.importOrder, 7)
    }

    func testGrammarItemDistractorsPreserveOrder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = GrammarBatch(index: 1)
        batch.deck = deck
        ctx.insert(batch)
        let item = GrammarItem(
            question: "Q",
            correct: "A",
            distractors: ["Z", "M", "B"],
            explanation: nil,
            importOrder: 0
        )
        item.batch = batch
        ctx.insert(item)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<GrammarItem>()).first!
        XCTAssertEqual(fetched.distractors, ["Z", "M", "B"])
    }

    func testGrammarCascadeDelete() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        for batchIndex in 1...2 {
            let batch = GrammarBatch(index: batchIndex)
            batch.deck = deck
            ctx.insert(batch)
            for j in 0..<3 {
                let item = GrammarItem(
                    question: "Q\(batchIndex)-\(j)",
                    correct: "A",
                    distractors: ["B", "C", "D"],
                    explanation: nil,
                    importOrder: j
                )
                item.batch = batch
                ctx.insert(item)
            }
        }
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GrammarBatch>()).count, 2)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GrammarItem>()).count, 6)

        ctx.delete(deck)
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GrammarDeck>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GrammarBatch>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GrammarItem>()).count, 0)
    }
}
