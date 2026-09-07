import Foundation

/// 由 Markdown 表格解析出的文法選擇題資料。
/// - question：題目／例句
/// - correct：正確答案
/// - distractors：干擾選項（固定為 3 個）
/// - explanation：解析說明（可省略）
struct ParsedGrammarItem: Equatable {
    let question: String
    let correct: String
    let distractors: [String]
    let explanation: String?
}

/// 將 Markdown 表格格式的文字解析為文法題（`ParsedGrammarItem`）的解析器。
/// 表格固定為 4 欄（題目、正解、干擾選項、解析），並會自動略過表頭列與分隔列。
enum GrammarMarkdownParser {
    /// 判斷第一欄是否為「題目」表頭的關鍵字（用於辨識並略過表頭列）。
    private static let questionHeaderKeywords: Set<String> = [
        "question", "sentence", "題目", "例句"
    ]
    /// 判斷第二欄是否為「正解」表頭的關鍵字（用於辨識並略過表頭列）。
    private static let correctHeaderKeywords: Set<String> = [
        "correct", "answer", "正解", "答案"
    ]

    /// 解析整份輸入文字，回傳成功解析的文法題與失敗行的錯誤清單。
    /// - Parameter input: Markdown 表格格式的原始文字。
    /// - Returns: `items` 為解析成功的文法題；`errors` 為無法解析的行。
    static func parse(_ input: String) -> (items: [ParsedGrammarItem], errors: [ParseError]) {
        var items: [ParsedGrammarItem] = []
        var errors: [ParseError] = []
        var seenSeparator = false

        let lines = input.components(separatedBy: .newlines)
        for (idx, rawLine) in lines.enumerated() {
            let lineNumber = idx + 1
            let trimmedWholeLine = rawLine.trimmingCharacters(in: .whitespaces)
            // 空白行不視為錯誤，直接略過。
            if trimmedWholeLine.isEmpty { continue }

            // 先去除首尾的表格邊界 `|`，再以 `|` 切割；保留空子字串以正確判斷欄位數。
            let contentForSplit = stripBoundaryPipes(trimmedWholeLine)
            let cells = contentForSplit
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let looksLikeTableRow = trimmedWholeLine.contains("|")

            // 分隔列（如 `|---|---|`）僅為表格樣式，略過但記錄已見到分隔列。
            if looksLikeTableRow && isSeparatorRow(cells: cells) {
                seenSeparator = true
                continue
            }

            // 表頭列只可能出現在資料開始前（尚無項目、尚未見分隔列），略過之。
            if looksLikeTableRow && items.isEmpty && !seenSeparator && isHeaderRow(cells: cells) {
                continue
            }

            // 文法題固定為 4 欄，欄位數不符即視為錯誤行。
            guard cells.count == 4 else {
                errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
                continue
            }

            let question = cells[0]
            let correct = cells[1]
            let distractorsRaw = cells[2]
            let explanationRaw = cells[3]

            // 題目與正解為必填，缺一即視為錯誤行。
            guard !question.isEmpty, !correct.isEmpty else {
                errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
                continue
            }

            // 干擾選項欄以逗號分隔多個選項。
            let distractors = distractorsRaw
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            // 干擾選項須恰為 3 個且皆非空白，否則無法組成 4 選 1 的題目，記為錯誤。
            guard distractors.count == 3, distractors.allSatisfy({ !$0.isEmpty }) else {
                errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
                continue
            }

            // 解析欄為空時視為未提供（nil）。
            let explanation: String? = explanationRaw.isEmpty ? nil : explanationRaw

            items.append(ParsedGrammarItem(
                question: question,
                correct: correct,
                distractors: distractors,
                explanation: explanation
            ))
        }
        return (items, errors)
    }

    /// 去除表格行首尾的邊界 `|`。
    /// 僅在同時具備首尾 `|` 時才移除，避免影響非表格格式的內容。
    private static func stripBoundaryPipes(_ line: String) -> String {
        guard line.count >= 2, line.hasPrefix("|"), line.hasSuffix("|") else {
            return line
        }
        var stripped = line
        stripped.removeFirst()
        stripped.removeLast()
        return stripped
    }

    /// 判斷是否為 Markdown 表格的分隔列（僅由 `-` 與 `:` 組成，如 `---`、`:--:`）。
    /// 至少須有一個非空欄位，才算有效分隔列。
    private static func isSeparatorRow(cells: [String]) -> Bool {
        let allowed: Set<Character> = ["-", ":"]
        var anyNonEmpty = false
        for cell in cells {
            if cell.isEmpty { continue }
            anyNonEmpty = true
            for ch in cell where !allowed.contains(ch) {
                return false
            }
        }
        return anyNonEmpty
    }

    /// 判斷是否為表頭列：需為 4 欄，且第一欄與第二欄分別命中題目、正解關鍵字。
    /// 比對前先轉小寫，以忽略英文大小寫差異。
    private static func isHeaderRow(cells: [String]) -> Bool {
        guard cells.count == 4 else { return false }
        let question = cells[0].lowercased()
        let correct = cells[1].lowercased()
        return questionHeaderKeywords.contains(question)
            && correctHeaderKeywords.contains(correct)
    }
}
