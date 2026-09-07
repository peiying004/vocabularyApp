import SwiftData
import XCTest
@testable import VocTest

final class GrammarItemImporterTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeParsed(count: Int, prefix: String = "q") -> [ParsedGrammarItem] {
        (0..<count).map {
            ParsedGrammarItem(
                question: "\(prefix)\($0)",
                correct: "a\($0)",
                distractors: ["x\($0)", "y\($0)", "z\($0)"],
                explanation: nil
            )
        }
    }

    private func batchSizes(of deck: GrammarDeck) -> [Int] {
        deck.grammarBatches.sorted { $0.index < $1.index }.map(\.items.count)
    }

    /// 每批的固定題數。期望值一律由此推導，容量調整時不需重寫測試。
    private var size: Int { GrammarItemImporter.chunkSize }

    func testFirstGrammarImportCreatesAlignedBatches() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        GrammarItemImporter.appendItems(makeParsed(count: size + 5), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(batchSizes(of: deck), [size, 5])
        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2]
        )
    }

    /// 文法側與單字側共用同一個批次尺寸。
    func testGrammarBatchSizeMatchesVocabularyBatchSize() {
        XCTAssertEqual(GrammarItemImporter.chunkSize, CardImporter.chunkSize)
    }

    func testSubsequentGrammarImportPreservesTrailingBatch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        GrammarItemImporter.appendItems(makeParsed(count: size + 5, prefix: "a"), to: deck, in: ctx)
        try ctx.save()

        // 第一次匯入後的尾批（未滿，5 題），第二次匯入不得動到它。
        let originalTrailingQuestions: [String] = deck.grammarBatches
            .first(where: { $0.index == 2 })!
            .items
            .sorted { $0.importOrder < $1.importOrder }
            .map(\.question)

        GrammarItemImporter.appendItems(makeParsed(count: 30, prefix: "b"), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(batchSizes(of: deck), [size, 5, 30])
        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2, 3]
        )

        let batch2Now = deck.grammarBatches.first(where: { $0.index == 2 })!
        XCTAssertEqual(batch2Now.items.count, 5)
        XCTAssertEqual(
            batch2Now.items.sorted { $0.importOrder < $1.importOrder }.map(\.question),
            originalTrailingQuestions
        )
        XCTAssertTrue(batch2Now.items.allSatisfy { $0.question.hasPrefix("a") })

        let batch3 = deck.grammarBatches.first(where: { $0.index == 3 })!
        XCTAssertTrue(batch3.items.allSatisfy { $0.question.hasPrefix("b") })
    }

    func testGrammarBatchIndicesAreSequentialAcrossImports() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        GrammarItemImporter.appendItems(makeParsed(count: size), to: deck, in: ctx)
        GrammarItemImporter.appendItems(makeParsed(count: size), to: deck, in: ctx)
        GrammarItemImporter.appendItems(makeParsed(count: size), to: deck, in: ctx)
        try ctx.save()

        XCTAssertEqual(
            deck.grammarBatches.sorted { $0.index < $1.index }.map(\.index),
            [1, 2, 3]
        )
    }

    // MARK: - Batch Capacity Invariant：匯入切批不得產生超過上限的批次

    func testGrammarImportNeverProducesOverCapacityBatch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = GrammarDeck(name: "Basic")
        ctx.insert(deck)

        GrammarItemImporter.appendItems(makeParsed(count: size * 2 + 7), to: deck, in: ctx)
        try ctx.save()

        XCTAssertTrue(deck.grammarBatches.allSatisfy { $0.items.count <= size })
    }
}
