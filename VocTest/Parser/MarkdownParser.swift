import Foundation

/// 由 Markdown 表格解析出的單字卡資料。
/// - word：英文單字
/// - partOfSpeech：詞性（可省略）
/// - translation：中文翻譯
struct ParsedCard: Equatable {
    let word: String
    let partOfSpeech: String?
    let translation: String
}

/// 記錄無法解析的行，供使用者定位錯誤來源。
/// - lineNumber：行號（從 1 起算）
/// - rawLine：未經處理的原始行內容
struct ParseError: Equatable {
    let lineNumber: Int
    let rawLine: String
}

/// 將 Markdown 表格格式的文字解析為單字卡（`ParsedCard`）的解析器。
/// 支援 2 欄（單字、翻譯）或 3 欄（單字、詞性、翻譯）的表格，
/// 並會自動略過表頭列與分隔列。
enum MarkdownParser {
    /// 判斷第一欄是否為「單字」表頭的關鍵字（用於辨識並略過表頭列）。
    private static let wordHeaderKeywords: Set<String> = [
        "word", "vocabulary", "term", "單字", "詞彙", "英文"
    ]
    /// 判斷第三欄是否為「翻譯」表頭的關鍵字（用於辨識並略過表頭列）。
    private static let translationHeaderKeywords: Set<String> = [
        "translation", "meaning", "翻譯", "中文", "釋義"
    ]

    /// 解析整份輸入文字，回傳成功解析的單字卡與失敗行的錯誤清單。
    /// - Parameter input: Markdown 表格格式的原始文字。
    /// - Returns: `cards` 為解析成功的單字卡；`errors` 為無法解析的行。
    static func parse(_ input: String) -> (cards: [ParsedCard], errors: [ParseError]) {
        var cards: [ParsedCard] = []
        var errors: [ParseError] = []
        var seenSeparator = false

        let lines = input.components(separatedBy: .newlines)
        for (idx, rawLine) in lines.enumerated() {
            let lineNumber = idx + 1
            let trimmedWholeLine = rawLine.trimmingCharacters(in: .whitespaces)
            // 空白行不視為錯誤，直接略過。
            if trimmedWholeLine.isEmpty {
                continue
            }

            // 先去除首尾的表格邊界 `|`，避免切割後產生多餘的空欄位。
            let contentForSplit = stripBoundaryPipes(trimmedWholeLine)

            // 以 `|` 切割各欄位；保留空子字串，才能正確判斷欄位數量。
            let cells = contentForSplit
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let looksLikeTableRow = trimmedWholeLine.contains("|")

            // 分隔列（如 `|---|---|`）僅為表格樣式，略過但記錄已見到分隔列。
            if looksLikeTableRow && isSeparatorRow(cells: cells) {
                seenSeparator = true
                continue
            }

            // 表頭列只可能出現在資料開始前（尚無卡片、尚未見分隔列），略過之。
            if looksLikeTableRow && cards.isEmpty && !seenSeparator && isHeaderRow(cells: cells) {
                continue
            }

            switch cells.count {
            case 3:
                // 3 欄格式：單字、詞性、翻譯；詞性為空時視為未提供（nil）。
                let word = cells[0]
                let pos = cells[1].isEmpty ? nil : cells[1]
                let translation = cells[2]
                // 單字與翻譯為必填，缺一即視為錯誤行。
                guard !word.isEmpty, !translation.isEmpty else {
                    errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
                    continue
                }
                cards.append(ParsedCard(word: word, partOfSpeech: pos, translation: translation))
            case 2:
                // 2 欄格式：單字、翻譯，無詞性。
                let word = cells[0]
                let translation = cells[1]
                // 單字與翻譯為必填，缺一即視為錯誤行。
                guard !word.isEmpty, !translation.isEmpty else {
                    errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
                    continue
                }
                cards.append(ParsedCard(word: word, partOfSpeech: nil, translation: translation))
            default:
                // 欄位數不為 2 或 3 的行無法對應資料格式，記為錯誤。
                errors.append(ParseError(lineNumber: lineNumber, rawLine: rawLine))
            }
        }
        return (cards, errors)
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

    /// 判斷是否為表頭列：需為 3 欄，且第一欄與第三欄分別命中單字、翻譯關鍵字。
    /// 比對前先轉小寫，以忽略英文大小寫差異。
    private static func isHeaderRow(cells: [String]) -> Bool {
        guard cells.count == 3 else { return false }
        let word = cells[0].lowercased()
        let translation = cells[2].lowercased()
        return wordHeaderKeywords.contains(word)
            && translationHeaderKeywords.contains(translation)
    }
}
