import XCTest
@testable import VocTest

final class GrammarMarkdownParserTests: XCTestCase {

    // MARK: - Task 2.1: Pipe-delimited parsing + GFM boundary

    func testGrammarFourCellRow() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形"
        )
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items, [
            ParsedGrammarItem(
                question: "I ___ to school every day.",
                correct: "go",
                distractors: ["goes", "going", "gone"],
                explanation: "主詞 I 用動詞原形"
            )
        ])
    }

    func testGrammarGFMTableRowWithBoundaryPipes() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "| I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形 |"
        )
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items, [
            ParsedGrammarItem(
                question: "I ___ to school every day.",
                correct: "go",
                distractors: ["goes", "going", "gone"],
                explanation: "主詞 I 用動詞原形"
            )
        ])
    }

    // MARK: - Task 2.2: Distractors CSV requires exactly 3 non-empty

    func testGrammarDistractorsThreeValid() {
        let (items, _) = GrammarMarkdownParser.parse(
            "Q | A | goes, going, gone | note"
        )
        XCTAssertEqual(items.first?.distractors, ["goes", "going", "gone"])
    }

    func testGrammarDistractorsTwoTokensIsParseError() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "I ___ to school. | go | goes,going | explanation"
        )
        XCTAssertEqual(items, [])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 1)
        XCTAssertEqual(errors[0].rawLine, "I ___ to school. | go | goes,going | explanation")
    }

    func testGrammarDistractorsFourTokensIsParseError() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "I ___ to school. | go | goes,going,gone,gonna | explanation"
        )
        XCTAssertEqual(items, [])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 1)
    }

    func testGrammarDistractorsEmptyMiddleTokenIsParseError() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "I ___ to school. | go | goes,,gone | explanation"
        )
        XCTAssertEqual(items, [])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 1)
    }

    func testGrammarDistractorsAllEmptyIsParseError() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "Q | A | ,, | note"
        )
        XCTAssertEqual(items, [])
        XCTAssertEqual(errors.count, 1)
    }

    // MARK: - Task 2.3: Explanation optional + blank/non-row + header + separator

    func testGrammarEmptyExplanationYieldsNil() {
        let (items, errors) = GrammarMarkdownParser.parse(
            "I ___ to school every day. | go | goes,going,gone |  "
        )
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items.first?.explanation, nil)
    }

    func testGrammarNonEmptyExplanationPreserved() {
        let (items, _) = GrammarMarkdownParser.parse(
            "I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形"
        )
        XCTAssertEqual(items.first?.explanation, "主詞 I 用動詞原形")
    }

    func testGrammarBlankLinesSkipped() {
        let input = """
        I ___ home. | go | goes,going,gone | note1


        She ___ tea. | drinks | drink,drinking,drank | note2
        """
        let (items, errors) = GrammarMarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].question, "I ___ home.")
        XCTAssertEqual(items[1].question, "She ___ tea.")
    }

    func testGrammarHeaderRowAtTopSkipped() {
        let input = """
        | question | correct | distractors | explanation |
        | -------- | ------- | ----------- | ----------- |
        | I ___ home. | go | goes,going,gone | note |
        """
        let (items, errors) = GrammarMarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].question, "I ___ home.")
    }

    func testGrammarChineseHeaderRowAtTopSkipped() {
        let input = """
        | 題目 | 正解 | distractors | explanation |
        | ---- | ---- | ----------- | ----------- |
        | I ___ home. | go | goes,going,gone | note |
        """
        let (items, errors) = GrammarMarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(items.count, 1)
    }

    func testGrammarDashOnlyLineWithoutPipeIsNotSeparator() {
        let (items, errors) = GrammarMarkdownParser.parse("---")
        XCTAssertEqual(items, [])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 1)
        XCTAssertEqual(errors[0].rawLine, "---")
    }

    func testGrammarYAMLFrontMatterDoesNotCloseHeaderDetection() {
        let input = """
        ---
        title: Grammar Basic unit1
        ---
        | question | correct | distractors | explanation |
        | -------- | ------- | ----------- | ----------- |
        | I ___ home. | go | goes,going,gone | note |
        """
        let (items, errors) = GrammarMarkdownParser.parse(input)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].question, "I ___ home.")
        // Front matter's --- lines and title: line are ParseError (3 non-blank non-table rows)
        XCTAssertEqual(errors.map(\.lineNumber), [1, 2, 3])
    }
}
