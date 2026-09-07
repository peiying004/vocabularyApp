## Context

MarkdownParser 目前只接受純 pipe 格式（每行以 `word | pos | translation` 或 `word | translation` 形式撰寫），這是為了 App 內文字框「隨便貼幾行就能匯入」的最小輸入格式。實務上，使用者已經開始在 `voc/` 底下用 Typora / Obsidian 風格的 GFM 表格記錄單字（每行兩端有 `|`、有表頭、有分隔線），這是主流 markdown 工具的預設表格語法，也是可以被 GitHub 直接渲染的格式。若 parser 能同時容忍 GFM 表格，使用者的既有筆記檔就能不改一個字直接匯入。

本次修改集中在 `MarkdownParser.parse` 這一個純函式（Parser 入口檔）。輸出型別 `ParsedCard` / `ParseError` 不變、匯入流程 UI 不變、SwiftData 持久化不變。

## Goals / Non-Goals

**Goals:**

- `MarkdownParser.parse` 對 GFM 表格檔（例如 `voc/多益單字們- unit1.md`）能產出正確的卡片，並且不對表頭列與分隔線發出 `ParseError`。
- 完全向後相容：既有的純 pipe 測試檔案（`MarkdownParserTests.swift` 目前的每一個測試）繼續通過而不需修改測試斷言。
- 表頭偵測採保守策略：只在檔案「還沒產出任何有效卡片、且還沒見過分隔線」時判定；避免把真的三欄卡片誤判為表頭。

**Non-Goals:**

- 不支援 YAML front matter（`---` 起訖區塊）、`#` 標題、清單、程式碼區塊等其他 markdown 結構；那些行仍會被記為 `ParseError`，UI 已經有「無效行（已跳過）」區塊顯示。
- 不支援依表頭順序重排欄位（例如若使用者寫 `翻譯 | 單字 | 詞性`，parser 不會依表頭重排；欄位順序固定為 word / pos / translation）。
- 不新增 UI；不改動 `ImportView`、`CardImporter`。
- 不改變空行、空欄、四欄以上等既有錯誤處理行為。

## Decisions

### Header keyword matching

表頭列偵測使用「關鍵字集合對應到欄位角色」的方式，而非「位置固定」。原因：使用者可能以中文或英文寫欄位名稱，也可能省略詞性欄。採白名單關鍵字（case-insensitive、trim 過的字串完全比對）：

- word 欄：`word`、`vocabulary`、`term`、`單字`、`詞彙`、`英文`
- pos 欄：`pos`、`part of speech`、`詞性`
- translation 欄：`translation`、`meaning`、`翻譯`、`中文`、`釋義`

判定規則：一行是 3 欄、且第 1 欄命中 word 集合、第 3 欄命中 translation 集合（第 2 欄可命中 pos 集合、也可以是任意字串——因為 pos 欄可留空並不常是關鍵字），即視為表頭。若條件不完全符合，視為一般資料列走原本流程。

**Alternatives considered:**

- 「檔案第一行永遠當表頭」：拒絕。使用者若貼的是純 pipe 內容、第一行就是有效單字，會被誤丟。
- 「見到分隔線後往回退一行當表頭」：拒絕。實作複雜、需要 lookahead。改為「只在還沒產卡、且還沒見過分隔線」的邊界條件內判定表頭，較好推理。

### Separator line detection

分隔線判定的前置條件：**原始行必須至少含一個 `|` 字元**。這排除 YAML front matter 的 `---` 這類「純破折號、無 pipe」的行，避免它們意外設定 `seenSeparator` 而關閉後續真正的 GFM 表頭偵測。門檻通過後，再套用「去掉前後 pipe、每格 trim 後只由 `-` 與 `:` 組成、且至少一格非空」的判定；分隔線一律靜默跳過，不列為 `ParseError`；並且見過分隔線後，關閉表頭偵測（不再把後續行當表頭）。

### Trim boundary pipes

在切欄之前先偵測：若整行 `trim` 後同時以 `|` 起頭且以 `|` 結尾，則剝除這兩個 `|`，再走原本的 `split(separator: "|", omittingEmptySubsequences: false)` + `trim` 邏輯。這一步讓一行 `| apple | n. | 蘋果 |` 在原邏輯下切出的空頭空尾 cell 被消去，恢復成 3 cells。

## Implementation Contract

**Behavior:**

`MarkdownParser.parse(_:)` 對含 GFM 表格語法的輸入，回傳的 `(cards, errors)` 內：

- 三欄／兩欄的資料列產出正確的 `ParsedCard`（欄位語意仍為 word / pos / translation，兩欄時 pos = nil）。
- 表頭列與分隔線不產出卡片、也不產出 `ParseError`。
- 其餘既有行為（空行跳過、空 pos 欄 → nil、欄數為 2 / 3 以外的行 → `ParseError`）維持不變。

**Interface / data shape:**

- 函式簽章不變：`static func parse(_ input: String) -> (cards: [ParsedCard], errors: [ParseError])`。
- `ParsedCard`、`ParseError` 型別不變。
- 內部可新增 private helper（例如 `isSeparatorRow`、`isHeaderRow`、`stripBoundaryPipes`），不對外暴露。

**Failure modes:**

- YAML front matter（`---` 三個連字號自己一行）：因為 `---` 這種行**不含任何 `|`**，separator/header 偵測都不會啟動；該行走既有 default 分支（切欄後只有 1 個 cell）→ `ParseError`。這個門檻同時保證了 YAML `---` 不會意外設定 `seenSeparator` 而關閉後續真正的 GFM 表頭偵測。front matter 內部的 `title:` `tags:` 等行也會被判為 2 或 3 欄外的無效行走 `ParseError`。使用者會在「無效行（已跳過）」區塊看到 `---`、`title:`、`tags:`、`# 標題` 這幾行，不影響有效資料匯入。
- `#` 標題行（例如 `# 多益單字們- unit1`）：切欄後只有 1 cell，走既有 default 分支 → `ParseError`。行為維持一致，使用者會在「無效行」區塊看到。

**Acceptance criteria:**

- `xcodebuild test -scheme VocTest -destination 'generic/platform=iOS Simulator'` 全數綠燈。
- 新增的測試至少覆蓋：純 GFM 表格檔匯入、GFM 表格帶表頭與分隔線、GFM 表格但表頭關鍵字不命中（應被當成一般卡片）、GFM 分隔線後接資料列、純 pipe 與 GFM 混合輸入、front matter 帶進來的邊界情況。
- 既有的 `MarkdownParserTests.swift` 所有測試維持通過且不修改斷言。
- 手動驗收：把 `voc/多益單字們- unit1.md` 完整內容貼進 App 匯入畫面，`ImportResult.cardsAdded == 40`，`parseErrors` 只包含 front matter / 標題那幾行（不含 40 個單字任何一行、不含分隔線、不含表頭列）。

**Scope boundaries:**

- 在範圍內：`VocTest/Parser/MarkdownParser.swift`、`VocTestTests/MarkdownParserTests.swift`、`openspec/changes/support-gfm-markdown-tables/specs/vocabulary-import/spec.md`。
- 不在範圍內：`ImportView`、`CardImporter`、`Card` model、UI 上「無效行」顯示樣式、front matter 忽略、`#` 標題忽略。

## Risks / Trade-offs

- 表頭關鍵字白名單可能漏掉罕見用字 → 若日後使用者用了新關鍵字（例如 `English word`、`釋意`），parser 會把該行當成一般卡片並失敗於欄數不符或內容非單字。可接受：由使用者反映後在關鍵字集合中補值即可。
- Front matter 中的 `---` 分隔線會被 parser 當成 GFM 分隔線靜默略過，但 `title: xxx` / `tags: [...]` 這幾行仍會列為 `ParseError`；使用者匯入 GFM 檔案時「無效行」區塊會顯示這幾行 → UX 上可能造成困惑。緩解：使用者可以自己把 front matter 刪掉；未來若確認要正式忽略 front matter，再另開一個 change 處理。
- 「還沒產卡且還沒見分隔線才判定表頭」的邊界條件，在只有一張表格的常見場景很直覺；但多張連續表格的檔案裡，只有第一張表的表頭會被跳過，後續表的表頭會被記為 `ParseError`。可接受：不在本次 scope 內，且 App 的匯入語意是「一次匯入一份單字表」。
