## 1. Parser 前置行處理

- [x] 1.1 在 MarkdownParser.parse 中實作「Trim boundary pipes」：當一行 trim 後同時以 `|` 起首、以 `|` 結尾時，剝除首尾兩個 `|` 後再進入原本的切欄邏輯，滿足 `GFM Table Row Boundary Pipes` 需求。行為契約：`| apple | n. | 蘋果 |` 產生 word=apple / pos=n. / translation=蘋果 一張卡；`| look forward to | 期待 |` 產生兩欄卡；`| give up |  | 放棄 |` 產生 pos=nil 的卡；皆零 ParseError。驗收：於 VocTestTests/MarkdownParserTests.swift 新增 `testGFMThreeCellRowWithBoundaryPipes`、`testGFMTwoCellRowWithBoundaryPipes`、`testGFMRowWithEmptyMiddleCell`，`xcodebuild test -scheme VocTest -destination 'generic/platform=iOS Simulator'` 通過。

## 2. GFM 分隔線與表頭跳過

- [x] 2.1 實作「Separator line detection」：parser 遇到「去掉前後 pipe、每格 trim 後只由 `-` 與 `:` 組成、且至少一格非空」的行時靜默跳過，滿足 `GFM Table Separator Line Skipping` 需求；記錄 parser 內部旗標，見過分隔線後關閉表頭判定。行為契約：`| --- | --- |`、`| :--- | :---: | ---: |` 不產卡、不產 ParseError；分隔線之後就算再遇到 `| word | pos | translation |` 也當成資料列而非表頭。驗收：新增 `testGFMSeparatorLineBetweenHeaderAndData`、`testGFMSeparatorWithAlignmentColonsSkipped`、`testGFMHeaderRowAfterSeparatorTreatedAsData` 綠燈。

- [x] 2.2 實作「Header keyword matching」：依 design 白名單建立 word/pos/translation 三組關鍵字集合（英文與繁中），套用 `GFM Table Header Row Skipping` 需求的五項條件（尚未產卡、未見分隔線、恰 3 欄、第 1 欄命中 word 集合、第 3 欄命中 translation 集合）。行為契約：`| word | pos | translation |` 於檔首被跳過；`| 單字 | 詞性 | 翻譯 |` 於檔首被跳過；`| foo | bar | baz |` 於檔首產一張卡（word=foo, pos=bar, translation=baz）；已產卡之後遇到 `| word | pos | translation |` 產一張 word=word 的卡。驗收：新增 `testGFMEnglishHeaderRowSkipped`、`testGFMChineseHeaderRowSkipped`、`testGFMHeaderLikeRowAfterFirstCardIsData`、`testGFMThreeCellNonMatchingKeywordsIsData` 綠燈。

## 3. 純 pipe 向後相容

- [x] 3.1 驗證 `Backward Compatibility With Plain Pipe Format` 需求：既有 VocTestTests/MarkdownParserTests.swift 全部測試不改動即維持通過；同時新增 `testMixedPlainAndGFMInput` 覆蓋純 pipe 與 GFM 混合行的情境（例如第 1 行 `apple | n. | 蘋果`、第 2 行 `| banana | n. | 香蕉 |`、第 3 行空行、第 4 行 `bad line | with | four | cells`，應產出 2 張卡 + 1 個 lineNumber=4 的 ParseError）。行為契約：不因新增 GFM 邏輯而讓純 pipe 行為漂移。驗收：`xcodebuild test -scheme VocTest` 全數綠燈，且既有測試檔的斷言沒有被修改。

## 4. 端對端手動驗收

- [x] 4.1 手動驗收使用者的 `voc/多益單字們- unit1.md` 匯入結果：於 iPhone 或 iOS Simulator 執行 App，建立 Deck「主題字彙」，把該 md 檔的完整內容貼進 ImportView，觀察畫面上的匯入結果。行為契約：`ImportResult.cardsAdded == 40`；「無效行（已跳過）」清單不含 40 個單字的任何一行、不含 `| ------------------- | ---- |:--------------------- |` 分隔線、不含 `| 單字 | 詞性 | 翻譯 |` 表頭列（可含 YAML front matter 的 `title:` / `tags:` 與 `# 多益單字們- unit1` 這幾行，屬於既知超出本次 scope 的無效行）。驗收：截圖或記錄匯入結果數字與無效行清單，附在此 change 的驗收筆記中回報。
