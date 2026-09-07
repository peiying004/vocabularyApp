import XCTest
@testable import VocTest

final class MarkdownParserTests: XCTestCase {

    // MARK: - Task 3.1: Three spec examples

    func testThreeCellLineWithPartOfSpeech() {
        let (cards, errors) = MarkdownParser.parse("apple | n. | 蘋果")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果")
        ])
    }

    func testTwoCellLineWithoutPartOfSpeech() {
        let (cards, errors) = MarkdownParser.parse("look forward to | 期待")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "look forward to", partOfSpeech: nil, translation: "期待")
        ])
    }

    func testThreeCellLineWithEmptyMiddleCell() {
        let (cards, errors) = MarkdownParser.parse("look forward to |  | 期待")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "look forward to", partOfSpeech: nil, translation: "期待")
        ])
    }

    // MARK: - Task 3.2: Blank line handling + invalid line reporting

    func testBlankAndWhitespaceLinesAreSilentlySkipped() {
        let input = "apple | n. | 蘋果\n\n  \nbanana | n. | 香蕉"
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果"),
            ParsedCard(word: "banana", partOfSpeech: "n.", translation: "香蕉")
        ])
    }

    func testMixedValidAndInvalidInputFromSpecExample() {
        // From specs/vocabulary-import/spec.md "Mixed valid and invalid input" example
        let input = """
        apple | n. | 蘋果
        look forward to | 期待
        look forward to |  | 期待
        bad line with four | | | cells
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果"),
            ParsedCard(word: "look forward to", partOfSpeech: nil, translation: "期待"),
            ParsedCard(word: "look forward to", partOfSpeech: nil, translation: "期待")
        ])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 4)
        XCTAssertEqual(errors[0].rawLine, "bad line with four | | | cells")
    }

    func testBlankLinesDoNotAffectLineNumberOfReportedErrors() {
        let input = "apple | n. | 蘋果\n\nbad line with four | | | cells"
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 3)
    }

    // MARK: - GFM Table Row Boundary Pipes

    func testGFMThreeCellRowWithBoundaryPipes() {
        let (cards, errors) = MarkdownParser.parse("| apple | n. | 蘋果 |")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果")
        ])
    }

    func testGFMTwoCellRowWithBoundaryPipes() {
        let (cards, errors) = MarkdownParser.parse("| look forward to | 期待 |")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "look forward to", partOfSpeech: nil, translation: "期待")
        ])
    }

    func testGFMRowWithEmptyMiddleCell() {
        let (cards, errors) = MarkdownParser.parse("| give up |  | 放棄 |")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "give up", partOfSpeech: nil, translation: "放棄")
        ])
    }

    // MARK: - GFM Table Separator Line Skipping

    func testGFMSeparatorLineBetweenHeaderAndData() {
        let input = """
        | word | pos | translation |
        | ---- | ---- | ---- |
        | apple | n. | 蘋果 |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果")
        ])
    }

    func testGFMSeparatorWithAlignmentColonsSkipped() {
        let (cards, errors) = MarkdownParser.parse("| :--- | :---: | ---: |")
        XCTAssertEqual(cards, [])
        XCTAssertEqual(errors, [])
    }

    func testGFMHeaderRowAfterSeparatorTreatedAsData() {
        let input = """
        | ---- | ---- | ---- |
        | word | pos | translation |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "word", partOfSpeech: "pos", translation: "translation")
        ])
    }

    // MARK: - GFM Table Header Row Skipping

    func testGFMEnglishHeaderRowSkipped() {
        let input = """
        | word | pos | translation |
        | ---- | ---- | ---- |
        | apple | n. | 蘋果 |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果")
        ])
    }

    func testGFMChineseHeaderRowSkipped() {
        let input = """
        | 單字 | 詞性 | 翻譯 |
        | ---- | ---- | ---- |
        | acute | adj. | 急性的 |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "acute", partOfSpeech: "adj.", translation: "急性的")
        ])
    }

    func testGFMHeaderLikeRowAfterFirstCardIsData() {
        let input = """
        | apple | n. | 蘋果 |
        | word | pos | translation |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果"),
            ParsedCard(word: "word", partOfSpeech: "pos", translation: "translation")
        ])
    }

    func testGFMThreeCellNonMatchingKeywordsIsData() {
        let (cards, errors) = MarkdownParser.parse("| foo | bar | baz |")
        XCTAssertEqual(errors, [])
        XCTAssertEqual(cards, [
            ParsedCard(word: "foo", partOfSpeech: "bar", translation: "baz")
        ])
    }

    // MARK: - YAML front matter interaction (no pipe → not separator)

    func testDashOnlyLineWithoutPipeIsNotSeparator() {
        let (cards, errors) = MarkdownParser.parse("---")
        XCTAssertEqual(cards, [])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 1)
        XCTAssertEqual(errors[0].rawLine, "---")
    }

    func testYAMLFrontMatterDoesNotCloseHeaderDetection() {
        let input = """
        ---
        title: TOEIC unit 1
        ---
        | 單字 | 詞性 | 翻譯 |
        | ---- | ---- | ---- |
        | acute | adj. | 急性的 |
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(cards, [
            ParsedCard(word: "acute", partOfSpeech: "adj.", translation: "急性的")
        ])
        let errorLines = errors.map(\.lineNumber)
        XCTAssertEqual(errorLines, [1, 2, 3])
    }

    // MARK: - Backward Compatibility With Plain Pipe Format (mixed)

    func testMixedPlainAndGFMInput() {
        let input = """
        apple | n. | 蘋果
        | banana | n. | 香蕉 |

        bad line | with | four | cells
        """
        let (cards, errors) = MarkdownParser.parse(input)
        XCTAssertEqual(cards, [
            ParsedCard(word: "apple", partOfSpeech: "n.", translation: "蘋果"),
            ParsedCard(word: "banana", partOfSpeech: "n.", translation: "香蕉")
        ])
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].lineNumber, 4)
        XCTAssertEqual(errors[0].rawLine, "bad line | with | four | cells")
    }
}
