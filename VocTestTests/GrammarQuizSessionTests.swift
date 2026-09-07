import SwiftData
import XCTest
@testable import VocTest

final class GrammarQuizSessionTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeItems(_ ctx: ModelContext, batch: GrammarBatch, count: Int) -> [GrammarItem] {
        (0..<count).map { i in
            let item = GrammarItem(
                question: "Q\(i)",
                correct: "A\(i)",
                distractors: ["D\(i)-1", "D\(i)-2", "D\(i)-3"],
                explanation: nil,
                importOrder: i
            )
            item.batch = batch
            ctx.insert(item)
            return item
        }
    }

    private func makeBatchWithItems(count: Int) throws -> (GrammarBatch, [GrammarItem]) {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)
        let batch = GrammarBatch(index: 1)
        batch.deck = deck
        ctx.insert(batch)
        let items = makeItems(ctx, batch: batch, count: count)
        try ctx.save()
        return (batch, items)
    }

    /// 未指定 sampleSize 時，一輪應涵蓋整批（預設值取自批次容量）。
    /// 這個測試鎖住「容量調大後測驗仍測整批」，避免容量與抽樣數脫鉤。
    func testGrammarRoundDefaultSampleSizeCoversFullBatch() throws {
        let capacity = GrammarItemImporter.chunkSize
        let (batch, _) = try makeBatchWithItems(count: capacity)
        let session = GrammarQuizSession(batch: batch)
        XCTAssertEqual(session.totalItemsInRound, capacity)
        XCTAssertEqual(session.remaining.count, capacity)
    }

    func testGrammarRoundSamplesUpTo20() throws {
        let (batch, items) = try makeBatchWithItems(count: 25)
        let session = GrammarQuizSession(batch: batch, sampleSize: 20)
        XCTAssertEqual(session.totalItemsInRound, 20)
        XCTAssertEqual(session.remaining.count, 20)
        // All picked items belong to the batch
        let itemIDs = Set(items.map(\.persistentModelID))
        XCTAssertTrue(session.remaining.allSatisfy { itemIDs.contains($0.persistentModelID) })
    }

    func testGrammarRoundIncludesAllWhenBatchSmallerThanSample() throws {
        let (batch, _) = try makeBatchWithItems(count: 8)
        let session = GrammarQuizSession(batch: batch, sampleSize: 20)
        XCTAssertEqual(session.totalItemsInRound, 8)
        XCTAssertEqual(session.remaining.count, 8)
    }

    func testGrammarChoicePoolIsItemOwned() throws {
        let (batch, items) = try makeBatchWithItems(count: 5)
        let session = GrammarQuizSession(items: items, batch: batch)
        let choices = Set(session.choicesForCurrent())
        let current = session.currentItem!
        let expected: Set<String> = Set([current.correct] + current.distractors)
        XCTAssertEqual(choices, expected)
        XCTAssertEqual(choices.count, 4)
    }

    func testGrammarWrongReQueueGapThree() throws {
        let (batch, items) = try makeBatchWithItems(count: 5)
        let session = GrammarQuizSession(items: items, batch: batch)
        let firstBefore = session.currentItem!
        // Answer wrongly
        _ = session.submit(.translation("intentionally wrong"))
        // Head is now items[1], items[0] re-inserted at min(remaining.count, 3) = 3
        // Remaining after submit: [items[1], items[2], items[3], items[0], items[4]]
        XCTAssertEqual(session.remaining.count, 5)
        XCTAssertNotEqual(session.remaining[0].persistentModelID, firstBefore.persistentModelID)
        XCTAssertEqual(session.remaining[3].persistentModelID, firstBefore.persistentModelID)
    }

    func testGrammarWrongReQueueOnShortQueue() throws {
        let (batch, items) = try makeBatchWithItems(count: 2)
        let session = GrammarQuizSession(items: items, batch: batch)
        let a = session.currentItem!
        _ = session.submit(.translation("wrong"))
        // Only two items; after removeFirst → [items[1]], insert(a, at: min(1, 3)=1) → [items[1], a]
        XCTAssertEqual(session.remaining.count, 2)
        XCTAssertNotEqual(session.remaining[0].persistentModelID, a.persistentModelID)
        XCTAssertEqual(session.remaining[1].persistentModelID, a.persistentModelID)
    }

    func testGrammarRoundFinishesOnAllCorrect() throws {
        let (batch, items) = try makeBatchWithItems(count: 3)
        let session = GrammarQuizSession(items: items, batch: batch)
        while let current = session.currentItem {
            _ = session.submit(.translation(current.correct))
        }
        XCTAssertTrue(session.isFinished)
    }

    func testGrammarResultSummaryCounts() throws {
        let (batch, items) = try makeBatchWithItems(count: 3)
        let session = GrammarQuizSession(items: items, batch: batch)
        // First item: wrong once, then correct.
        _ = session.submit(.translation("wrong"))
        // Now second and third are ahead of the re-queued first. Answer all correct.
        while let current = session.currentItem {
            _ = session.submit(.translation(current.correct))
        }
        let summary = session.resultSummary()
        XCTAssertEqual(summary.correctCount, 2)
        XCTAssertEqual(summary.wrongTaps, 1)
        XCTAssertEqual(summary.mistakeItems.count, 1)
    }

    func testGrammarDontKnowIsCountedAsWrong() throws {
        let (batch, items) = try makeBatchWithItems(count: 2)
        let session = GrammarQuizSession(items: items, batch: batch)
        _ = session.submit(.dontKnow)
        while let current = session.currentItem {
            _ = session.submit(.translation(current.correct))
        }
        let summary = session.resultSummary()
        XCTAssertEqual(summary.wrongTaps, 1)
        XCTAssertEqual(summary.mistakeItems.count, 1)
    }

    // MARK: - Task 4.2: MistakeQuiz

    func testMistakeGrammarSessionChoicesFromItem() throws {
        let (batch, items) = try makeBatchWithItems(count: 4)
        let subset = [items[1], items[3]]
        let session = GrammarMistakeQuiz.session(from: subset, in: batch)
        let choices = Set(session.choicesForCurrent())
        let current = session.currentItem!
        XCTAssertEqual(choices, Set([current.correct] + current.distractors))
    }

    func testMistakeGrammarSessionWrongIncrementsWrongCount() throws {
        let (batch, items) = try makeBatchWithItems(count: 3)
        let subset = [items[0]]
        let session = GrammarMistakeQuiz.session(from: subset, in: batch)
        let before = items[0].wrongCount
        _ = session.submit(.translation("wrong"))
        XCTAssertEqual(items[0].wrongCount, before + 1)
    }

    func testMistakeGrammarSessionDontKnowIncrementsWrongCount() throws {
        let (batch, items) = try makeBatchWithItems(count: 3)
        let subset = [items[0]]
        let session = GrammarMistakeQuiz.session(from: subset, in: batch)
        let before = items[0].wrongCount
        _ = session.submit(.dontKnow)
        XCTAssertEqual(items[0].wrongCount, before + 1)
    }
}
