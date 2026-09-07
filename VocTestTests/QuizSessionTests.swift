import SwiftData
import XCTest
@testable import VocTest

final class QuizSessionTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Deck.self, Batch.self, Card.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeBatch(cardCount: Int, in ctx: ModelContext, deck: Deck? = nil, batchIndex: Int = 1, prefix: String = "w") -> Batch {
        let owningDeck = deck ?? {
            let d = Deck(name: "TestDeck")
            ctx.insert(d)
            return d
        }()
        let batch = Batch(index: batchIndex)
        batch.deck = owningDeck
        ctx.insert(batch)
        for j in 0..<cardCount {
            let card = Card(
                word: "\(prefix)\(j)",
                partOfSpeech: "n.",
                translation: "\(prefix)t\(j)",
                importOrder: j
            )
            card.batch = batch
            ctx.insert(card)
        }
        return batch
    }

    // MARK: - Task 7.1: Main quiz round composition

    /// 一輪測驗最多抽出批次容量的題數；預設值取自 `CardImporter.chunkSize`，
    /// 因此容量調整時這個測試不需重寫。
    func testMainQuizRoundCappedAtBatchCapacityForLargeBatch() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let capacity = CardImporter.chunkSize
        let batch = makeBatch(cardCount: capacity * 3 + 10, in: ctx)

        let session = QuizSession(batch: batch)
        XCTAssertEqual(session.totalCardsInRound, capacity)
        XCTAssertEqual(session.remaining.count, capacity)
    }

    func testMainQuizRoundIncludesAllCardsWhenBatchIsSmaller() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 12, in: ctx)

        let session = QuizSession(batch: batch)
        XCTAssertEqual(session.totalCardsInRound, 12)
        XCTAssertEqual(session.remaining.count, 12)
    }

    func testRoundFinishesAfterAllCorrectAnswers() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 12, in: ctx)

        let session = QuizSession(batch: batch)
        XCTAssertFalse(session.isFinished)
        while let c = session.currentCard {
            _ = session.submit(.translation(c.translation))
        }
        XCTAssertTrue(session.isFinished)
    }

    // MARK: - Task 7.3: Distractor selection

    func testDistractorsComeFromSameBatchAndDifferFromCorrect() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: CardImporter.chunkSize, in: ctx)
        let allTranslations = Set(batch.cards.map(\.translation))

        let session = QuizSession(cards: batch.cards, batch: batch)
        for trial in 0..<100 {
            guard let card = session.currentCard else { break }
            let distractors = session.pickDistractors(for: card)
            XCTAssertEqual(distractors.count, 3, "trial \(trial): wrong distractor count")
            XCTAssertFalse(distractors.contains(card.translation), "trial \(trial): correct leaked into distractors")
            for d in distractors {
                XCTAssertTrue(allTranslations.contains(d), "trial \(trial): distractor not from same batch")
            }
        }
    }

    func testDistractorsFallBackToOtherBatchesWhenBatchIsTooSmall() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let deck = Deck(name: "TestDeck")
        ctx.insert(deck)
        let smallBatch = makeBatch(cardCount: 3, in: ctx, deck: deck, batchIndex: 1, prefix: "s")
        let otherBatch = makeBatch(cardCount: CardImporter.chunkSize, in: ctx, deck: deck, batchIndex: 2, prefix: "o")
        let smallBatchTranslations = Set(smallBatch.cards.map(\.translation))
        let otherBatchTranslations = Set(otherBatch.cards.map(\.translation))

        let session = QuizSession(cards: smallBatch.cards, batch: smallBatch)
        for trial in 0..<100 {
            guard let card = session.currentCard else { break }
            let distractors = session.pickDistractors(for: card)
            XCTAssertEqual(distractors.count, 3, "trial \(trial): expected 3 distractors")
            // 2 should be from smallBatch (the other 2 cards), 1 from otherBatch
            let fromSame = distractors.filter { smallBatchTranslations.contains($0) }
            let fromOther = distractors.filter { otherBatchTranslations.contains($0) }
            XCTAssertEqual(fromSame.count, 2, "trial \(trial): wrong same-batch count")
            XCTAssertEqual(fromOther.count, 1, "trial \(trial): wrong cross-batch count")
            XCTAssertFalse(distractors.contains(card.translation))
        }
    }

    // MARK: - Task 7.4: Wrong answer re-queue with gap

    func testWrongSelectionReQueuesCardWithThreeCardGap() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 6, in: ctx)
        let cards = batch.cards.sorted { $0.importOrder < $1.importOrder }

        let session = QuizSession(cards: cards, batch: batch)
        XCTAssertEqual(session.remaining.map(\.word), ["w0", "w1", "w2", "w3", "w4", "w5"])

        let cardA = cards[0]
        XCTAssertEqual(cardA.wrongCount, 0)
        let result = session.submit(.translation("wrong-translation"))
        if case .wrong(let correct) = result {
            XCTAssertEqual(correct, cardA.translation)
        } else {
            XCTFail("expected .wrong result")
        }
        XCTAssertEqual(cardA.wrongCount, 1)
        XCTAssertEqual(session.remaining.map(\.word), ["w1", "w2", "w3", "w0", "w4", "w5"])
    }

    func testWrongAnswerOnShortQueueClampsReQueuePosition() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 2, in: ctx)
        let cards = batch.cards.sorted { $0.importOrder < $1.importOrder }

        let session = QuizSession(cards: cards, batch: batch)
        XCTAssertEqual(session.remaining.map(\.word), ["w0", "w1"])

        _ = session.submit(.translation("nope"))
        XCTAssertEqual(session.remaining.map(\.word), ["w1", "w0"])
    }

    func testDontKnowTakesSameBranchAsWrongAnswer() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 6, in: ctx)
        let cards = batch.cards.sorted { $0.importOrder < $1.importOrder }

        let session = QuizSession(cards: cards, batch: batch)
        let cardA = cards[0]
        let result = session.submit(.dontKnow)
        if case .wrong(let correct) = result {
            XCTAssertEqual(correct, cardA.translation)
        } else {
            XCTFail("dontKnow should yield .wrong")
        }
        XCTAssertEqual(cardA.wrongCount, 1)
        XCTAssertEqual(session.remaining.map(\.word), ["w1", "w2", "w3", "w0", "w4", "w5"])
    }

    // MARK: - Task 8.3: Mistake quiz reuses the same engine

    func testMistakeQuizUsesSameEngineAndLooksAtSpecifiedCards() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: CardImporter.chunkSize, in: ctx)
        let mistakeCards = Array(batch.cards.prefix(4))

        let session = MistakeQuiz.session(from: mistakeCards, in: batch)
        XCTAssertEqual(session.totalCardsInRound, 4)
        XCTAssertEqual(Set(session.remaining.map(\.word)), Set(mistakeCards.map(\.word)))
    }

    func testMistakeQuizWrongTapsContinueToIncrementWrongCount() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: CardImporter.chunkSize, in: ctx)
        let mistakeCards = Array(batch.cards.prefix(4))

        // Pre-condition: a card may already have wrongCount from a prior main quiz.
        mistakeCards[0].recordWrong()
        mistakeCards[0].recordWrong()
        XCTAssertEqual(mistakeCards[0].wrongCount, 2)

        // Make each of the 4 cards wrong exactly once in the mistake quiz.
        // After all are wrong + re-queued, drain by answering correctly.
        let session = MistakeQuiz.session(from: mistakeCards, in: batch)

        var seen: Set<PersistentIdentifier> = []
        while !session.isFinished, seen.count < mistakeCards.count {
            guard let current = session.currentCard else { break }
            if !seen.contains(current.persistentModelID) {
                let before = current.wrongCount
                _ = session.submit(.dontKnow)
                XCTAssertEqual(
                    current.wrongCount, before + 1,
                    "wrongCount should increment for \(current.word)"
                )
                seen.insert(current.persistentModelID)
            } else {
                _ = session.submit(.translation(current.translation))
            }
        }
        while let c = session.currentCard {
            _ = session.submit(.translation(c.translation))
        }

        XCTAssertEqual(mistakeCards[0].wrongCount, 3, "card[0] started at 2, +1 from mistake quiz")
        for card in mistakeCards.dropFirst() {
            XCTAssertEqual(card.wrongCount, 1, "\(card.word) should have exactly 1 wrong tap")
        }
    }

    func testMistakeQuizSecondRoundReusesMistakeCards() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: CardImporter.chunkSize, in: ctx)
        let mistakeCards = Array(batch.cards.prefix(4))

        let session1 = MistakeQuiz.session(from: mistakeCards, in: batch)
        var seen: Set<PersistentIdentifier> = []
        while !session1.isFinished, seen.count < mistakeCards.count {
            guard let current = session1.currentCard else { break }
            if !seen.contains(current.persistentModelID) {
                _ = session1.submit(.dontKnow)
                seen.insert(current.persistentModelID)
            } else {
                _ = session1.submit(.translation(current.translation))
            }
        }
        while let c = session1.currentCard {
            _ = session1.submit(.translation(c.translation))
        }

        let summary = session1.resultSummary()
        XCTAssertEqual(summary.mistakeCards.count, 4)
        XCTAssertEqual(
            Set(summary.mistakeCards.map(\.word)),
            Set(mistakeCards.map(\.word))
        )

        // Build the next round from this result and verify card set matches.
        let session2 = MistakeQuiz.session(from: summary.mistakeCards, in: batch)
        XCTAssertEqual(session2.totalCardsInRound, 4)
    }

    // MARK: - Round result summary

    func testResultSummaryReflectsRoundOutcome() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let batch = makeBatch(cardCount: 6, in: ctx)
        let cards = batch.cards.sorted { $0.importOrder < $1.importOrder }

        let session = QuizSession(cards: cards, batch: batch)
        // Make cardA wrong twice, others correct first time.
        _ = session.submit(.translation("wrong1"))  // A wrong (now re-queued)
        _ = session.submit(.translation(cards[1].translation))  // B correct
        _ = session.submit(.translation(cards[2].translation))  // C correct
        _ = session.submit(.translation(cards[3].translation))  // D correct
        _ = session.submit(.translation("wrong2"))  // A wrong again (re-queued)
        // After this, remaining should contain A and remaining cards
        while let c = session.currentCard {
            _ = session.submit(.translation(c.translation))
        }
        let summary = session.resultSummary()
        XCTAssertEqual(summary.correctCount, 5)
        XCTAssertEqual(summary.wrongTaps, 2)
        XCTAssertEqual(summary.mistakeCards.map(\.word), ["w0"])
    }
}
