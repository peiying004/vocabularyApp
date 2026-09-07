import SwiftData
import XCTest
@testable import VocTest

/// Task 9.1: end-to-end acceptance per design.md "Acceptance criteria".
/// Each test corresponds to a specific bullet (a)..(e).
final class AcceptanceTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeParsedCards(count: Int, prefix: String = "w") -> [ParsedCard] {
        (0..<count).map {
            ParsedCard(word: "\(prefix)\($0)", partOfSpeech: "n.", translation: "\(prefix)t\($0)")
        }
    }

    /// 每批的固定張數。期望值一律由此推導，容量調整時不需重寫測試。
    private var size: Int { CardImporter.chunkSize }

    // MARK: - (a) 匯入空 deck → 切成滿批加一個餘數批

    func test_a_ImportIntoEmptyDeckProducesFullBatchesPlusRemainder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "Acceptance")
        ctx.insert(deck)

        CardImporter.appendCards(makeParsedCards(count: size * 3 + 10), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.cards.count),
            [size, size, size, 10]
        )
    }

    // MARK: - (b) 再匯入 → 新批次接在後面，且原本未滿的尾批不被回填

    func test_b_SubsequentImportKeepsTrailingBatchIntact() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "Acceptance")
        ctx.insert(deck)
        CardImporter.appendCards(makeParsedCards(count: size * 3 + 10, prefix: "a"), to: deck, in: ctx)
        try ctx.save()

        CardImporter.appendCards(makeParsedCards(count: size + 20, prefix: "b"), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.cards.count),
            [size, size, size, 10, size, 20]
        )
        let trailingBatch = deck.batches.first(where: { $0.index == 4 })!
        XCTAssertEqual(trailingBatch.cards.count, 10)
        XCTAssertTrue(trailingBatch.cards.allSatisfy { $0.word.hasPrefix("a") })
    }

    // MARK: - (c) 解析 4 行 example 字串得到 3 個 card + 1 個 ParseError(line=4)

    func test_c_FourLineExampleProducesThreeCardsAndOneError() throws {
        let input = """
        apple | n. | 蘋果
        look forward to | 期待
        look forward to |  | 期待
        bad line with four | | | cells
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 4)
    }

    // MARK: - (d) 全對的一整批 round 結束時 Result 顯示 全對/0

    func test_d_AllCorrectFullBatchRoundShowsAllCorrectAndZeroWrong() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "Acceptance")
        ctx.insert(deck)
        CardImporter.appendCards(makeParsedCards(count: size), to: deck, in: ctx)
        try ctx.save()

        let batch = deck.batches.first!
        let session = QuizSession(batch: batch)
        XCTAssertEqual(session.totalCardsInRound, size)

        while let c = session.currentCard {
            _ = session.submit(.translation(c.translation))
        }
        let summary = session.resultSummary()
        XCTAssertEqual(summary.correctCount, size)
        XCTAssertEqual(summary.wrongTaps, 0)
        XCTAssertEqual(summary.mistakeCards.count, 0)
    }

    // MARK: - (e) 前 3 題答錯其餘答對 → 每張重出間隔至少 3 題，最終全對才結束

    func test_e_FirstThreeWrongOthersCorrectRequeuesWithGapAndFinishesOnlyWhenAllCorrect() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "Acceptance")
        ctx.insert(deck)

        // Use a deterministic 10-card queue (not a full batch, to keep the assertion tight).
        let parsedCards = makeParsedCards(count: 10)
        CardImporter.appendCards(parsedCards, to: deck, in: ctx)
        try ctx.save()
        let batch = deck.batches.first!
        let orderedCards = batch.cards.sorted { $0.importOrder < $1.importOrder }

        let session = QuizSession(cards: orderedCards, batch: batch)
        let wrongIDs = Set(orderedCards.prefix(3).map(\.persistentModelID))
        var encounterIndexByCard: [PersistentIdentifier: [Int]] = [:]
        var step = 0
        var wrongTapsFromFirstThree = 0

        while let current = session.currentCard {
            encounterIndexByCard[current.persistentModelID, default: []].append(step)
            if wrongIDs.contains(current.persistentModelID),
               encounterIndexByCard[current.persistentModelID]!.count == 1 {
                _ = session.submit(.translation("wrong-answer"))
                wrongTapsFromFirstThree += 1
            } else {
                _ = session.submit(.translation(current.translation))
            }
            step += 1
        }

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(wrongTapsFromFirstThree, 3, "exactly 3 wrong taps from the first 3 cards")

        // Each re-queued card must have at least 3 intervening questions between
        // its first appearance and its second appearance.
        for cardID in wrongIDs {
            let indices = encounterIndexByCard[cardID] ?? []
            XCTAssertEqual(indices.count, 2, "card should be seen exactly twice (once wrong, once correct)")
            if indices.count >= 2 {
                let gap = indices[1] - indices[0] - 1
                XCTAssertGreaterThanOrEqual(gap, 3, "expected ≥3 intervening questions before re-appearance, got \(gap)")
            }
        }

        let summary = session.resultSummary()
        XCTAssertEqual(summary.correctCount, 7)  // 10 - 3 mistake cards = 7 first-try-correct
        XCTAssertEqual(summary.wrongTaps, 3)
        XCTAssertEqual(summary.mistakeCards.count, 3)
    }
}
