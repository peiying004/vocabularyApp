## Why

使用者已經開始把單字放在 `voc/` 資料夾下的 markdown 檔案裡（例如 `voc/多益單字們- unit1.md`），這些檔案是用 GitHub-Flavored Markdown 表格語法撰寫的：每行兩端都有 `|`、有表頭列（`| 單字 | 詞性 | 翻譯 |`）、有 `| --- | --- |` 分隔線。這是 Typora、Obsidian、Notion 等常見編輯器匯出的預設 markdown 表格格式，也是使用者未來新增「主題字彙」分組時預期會持續採用的格式。

目前的 MarkdownParser 只接受「純 pipe」格式（無兩端 `|`、無表頭、無分隔線），因此若把 `voc/多益單字們- unit1.md` 直接貼進 App 或用檔案選擇器匯入，整份檔案的每一行（包含 40 個實際單字、1 個表頭、1 個分隔線）都會被判為 `ParseError`，使用者實際上匯入不到任何卡片。為了讓使用者不用學新的手寫格式、也不用每次都手動改檔案，parser 需要能容忍 GFM 表格語法。

## What Changes

- 擴充 `MarkdownParser.parse`：在既有的切欄邏輯之前，先偵測並剝除一行兩端的 `|`；表頭分隔線與表頭列會被判定為「非資料列」並靜默跳過（不計入 `ParseError`）。
- 表頭分隔線判定：一行去掉前後 pipe、每格 trim 後只由字元 `-` 與 `:` 組成，且至少一格非空，即為分隔線。例如 `| --- | --- | :---: |` 或 `| ---- | ---- |:---- |` 都算。
- 表頭列判定（保守）：只在該檔案尚未產出任何有效卡片、且尚未見過分隔線的情況下，若該行是恰好 3 欄，且欄位內容命中預先定義的表頭關鍵字集合（英文與繁中皆支援：`word/單字/vocabulary`、`pos/part of speech/詞性`、`translation/meaning/翻譯/中文`），才視為表頭並跳過。避免把真的三欄卡片誤判為表頭。
- 純 pipe 舊格式 100% 向後相容：既有 `MarkdownParserTests.swift` 的所有測試須維持不改動即可通過。
- 空行、空欄（`phrase |  | translation`）、四欄以上等既有行為維持不變。

## Non-Goals (optional)

- 不支援任意 markdown（僅支援 pipe-based 表格）：清單、標題、程式碼區塊等結構若混在檔案中，parser 仍當作無效資料列處理（會產生 `ParseError`，符合既有行為）。若使用者的檔案有 YAML front matter 或 `#` 標題（就像 `voc/多益單字們- unit1.md` 那樣），這些行會被視為無效行而列在「無效行（已跳過）」— 本次不處理，因為對匯入正確性沒有影響。
- 不改動 UI：`ImportView` 的貼上／檔案選擇流程不變。
- 不新增分批規則：50 張一批的規則保留原樣。
- 不做「智能偵測」語意欄位順序（例如若表頭是 `翻譯 | 單字 | 詞性`，parser 不會依表頭重排）：欄位順序仍固定為 word / pos / translation。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `vocabulary-import`：`MarkdownParser` 額外接受 GFM 表格格式（兩端 pipe、表頭分隔線、表頭列跳過）。

## Impact

- Affected specs: vocabulary-import (modified — 新增三個 requirement / 或於既有 `Pipe-Delimited Line Parsing` requirement 下擴充 scenarios)
- Affected code:
  - Modified: VocTest/Parser/MarkdownParser.swift
  - Modified: VocTestTests/MarkdownParserTests.swift（新增 GFM 表格、表頭列、分隔線、混合 pipe/GFM 情境的測試）
  - New: (none)
  - Removed: (none)
