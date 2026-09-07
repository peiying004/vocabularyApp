import SwiftData
import XCTest
@testable import VocTest

final class CardImporterTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeParsedCards(count: Int, prefix: String = "w") -> [ParsedCard] {
        (0..<count).map {
            ParsedCard(word: "\(prefix)\($0)", partOfSpeech: "n.", translation: "t\($0)")
        }
    }

    private func batchSizes(of deck: Deck) -> [Int] {
        deck.batches.sorted { $0.index < $1.index }.map(\.cards.count)
    }

    /// 每批的固定張數。期望值一律由此推導，容量調整時不需重寫測試。
    private var size: Int { CardImporter.chunkSize }

    // MARK: - 匯入空 deck：切成滿批加一個餘數批（chunkSize 為 40 時即 40/40/40/10）

    func testFirstImportSplitsIntoFullBatchesWithRemainder() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        CardImporter.appendCards(makeParsedCards(count: size * 3 + 10), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(batchSizes(of: deck), [size, size, size, 10])
        XCTAssertEqual(deck.batches.sorted { $0.index < $1.index }.map(\.index), [1, 2, 3, 4])
    }

    // MARK: - 既有的未滿尾批不會被回填

    func testSubsequentImportPreservesExistingTrailingBatch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        CardImporter.appendCards(makeParsedCards(count: size * 3 + 10, prefix: "a"), to: deck, in: ctx)
        try ctx.save()

        // 第一次匯入後的尾批（未滿，10 張），第二次匯入不得動到它。
        let trailingIndex = 4
        let originalTrailingWordSet: Set<String> = Set(
            deck.batches.first(where: { $0.index == trailingIndex })!.cards.map(\.word)
        )

        CardImporter.appendCards(makeParsedCards(count: size + 20, prefix: "b"), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(batchSizes(of: deck), [size, size, size, 10, size, 20])
        XCTAssertEqual(
            deck.batches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2, 3, 4, 5, 6]
        )

        let trailingNow = deck.batches.first(where: { $0.index == trailingIndex })!
        XCTAssertEqual(trailingNow.cards.count, 10)
        XCTAssertEqual(Set(trailingNow.cards.map(\.word)), originalTrailingWordSet)
        XCTAssertTrue(trailingNow.cards.allSatisfy { $0.word.hasPrefix("a") })

        // 新批次只包含第二次匯入的卡片。
        let batch5 = deck.batches.first(where: { $0.index == 5 })!
        let batch6 = deck.batches.first(where: { $0.index == 6 })!
        XCTAssertTrue(batch5.cards.allSatisfy { $0.word.hasPrefix("b") })
        XCTAssertTrue(batch6.cards.allSatisfy { $0.word.hasPrefix("b") })
    }

    // MARK: - Batch Capacity Invariant：匯入切批不得產生超過上限的批次

    func testImportNeverProducesOverCapacityBatch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TOEIC")
        ctx.insert(deck)

        CardImporter.appendCards(makeParsedCards(count: size * 3 + 10), to: deck, in: ctx)
        try ctx.save()

        XCTAssertTrue(deck.batches.allSatisfy { $0.cards.count <= size })
    }
}
