## 1. 專案初始化

- [x] 1.1 在 `VocTest/` 建立 SwiftUI app target 並依 design 的 **Xcode project layout** 決定切出 `Models/`、`Parser/`、`ReviewEngine/`、`Views/` 四個資料夾，確保純邏輯資料夾不引入 SwiftUI；驗證：用 Xcode 打開專案可成功編譯並執行進入空白主畫面，且 `grep -r SwiftUI VocTest/Parser VocTest/ReviewEngine` 無命中。
- [x] 1.2 設定 iOS 17 為最低部署版本，並在 `Info.plist` 註冊 `.md`、`.txt` 為可讀取的 document type，讓後續 **Import Entry Points** 的檔案選擇器能列出這兩種副檔名；驗證：模擬器開啟 `UIDocumentPickerViewController` 後可以看到並選取 `.md` 與 `.txt` 檔。

## 2. 資料模型（SwiftData）

- [x] 2.1 用 SwiftData 建立 `Deck`、`Batch`、`Card` 三個 @Model 類別並串好 cascade-delete，落實 design 的 **SwiftData for persistence** 與 **Deck → Batch → Card data shape** 決定，以及 spec 的 **Deck-Batch-Card Hierarchy** 需求；驗證：XCTest 以 in-memory `ModelContainer` 建立 1 deck → 3 batch → 130 card，刪除 deck 後查 batch 與 card 數量皆為 0。
- [x] 2.2 為 `Card` 加上 `word`、`partOfSpeech?`、`translation`、`wrongCount`（預設 0）、`importOrder` 欄位以符合 **Card Fields** 需求，並讓 `wrongCount` 只能透過 `recordWrong()` 之類專用 API 遞增以實作 **Wrong Count Is Monotonic**；驗證：XCTest (a) 寫入 `Card(word=apple, pos=n., translation=蘋果, wrongCount=5, importOrder=12)` 後重啟容器再讀出，五欄全相等；(b) 對 `wrongCount=3` 的卡呼叫 `recordWrong()` 兩次後值為 5，沒有任何 API 可以使其減少。
- [x] 2.3 為 `Batch` 加上 1-based `index`，並讓「新增 card 到既有 batch」與「變更 batch index」在 API 層不可為，符合 **Batch Index And Immutability** 需求；驗證：XCTest 嘗試對已存在 batch 追加 card，必須是編譯不通過或執行時拋出明確錯誤；新增三個 batch 後 indices 為 1、2、3。

## 3. Markdown 解析器

- [x] 3.1 在 `VocTest/Parser/MarkdownParser.swift` 實作 design 的 **Pipe-delimited markdown parser** 與 spec 的 **Pipe-Delimited Line Parsing**：以 `|` 切欄並 trim 每格，三欄 → `(word, pos, translation)`、兩欄 → `(word, nil, translation)`、三欄中間空 → `(word, nil, translation)`；驗證：XCTest 餵入 spec 三個範例（`apple | n. | 蘋果`、`look forward to | 期待`、`look forward to |  | 期待`）並逐一比對輸出欄位。
- [x] 3.2 為解析器補上 **Blank Line Handling** 與 **Invalid Line Reporting**：空白／純空白行靜默跳過，欄位數既非 2 也非 3 的行回傳 `ParseError(lineNumber, rawLine)` 並繼續處理；驗證：XCTest 餵入「Mixed valid and invalid input」example 表格四行，斷言輸出為 3 個 card + 1 個 `ParseError(lineNumber=4)`，且空白行不影響行號計算。

## 4. 匯入與批次

- [x] 4.1 實作將 `parsedCards` 寫入 deck 的服務函式，落實 design 的 **Automatic 50-card batching with immutable trailing batch** 與 spec 的 **Automatic 50-Card Batching On Persist**：每 50 張新卡開一批、剩餘自成最後一批、既有 batch 內容與 index 永不變；驗證：XCTest (a) 對空 deck 匯入 130 → 批次 50/50/30；(b) 再匯入 60 → 批次序列變為 50/50/30/50/10 且原第 3 批仍是 30 張。
- [x] 4.2 實作 **Import Entry Points**：`Views/ImportView.swift` 提供貼上文字框與 deck 選擇 + 觸發匯入；另接 `.fileImporter` 讓使用者從 iOS Files 選 `.md`/`.txt`，兩條路徑共用同一個解析與批次服務；驗證：模擬器手動跑兩條路徑，貼上 130 行 markdown 與選一個 `.md` 檔分別都正確產生批次／卡片，且 `ParseError` 在畫面上以「行號 + 原始行文字」呈現。

## 5. 導覽 UI

- [x] 5.1 實作 `DeckListView`、`BatchListView`、`BatchHomeView` 三個畫面，符合 **Navigation Surfaces** 需求：Deck List 支援建立新 deck 並顯示空狀態提示；Batch List 每列顯示 index、卡數、批次 cards 的 wrongCount 加總；Batch Home 提供「先複習所有單字」與「直接開始測驗」兩顆動作鈕；驗證：模擬器手動跑空 deck → 建立「TOEIC 常考」→ 匯入 50 張並造 7 次錯 → 開 Batch List，比對列上顯示 `index=1, count=50, wrongCount=7`，再進 Batch Home 看到兩顆按鈕。

## 6. 預習畫面

- [x] 6.1 實作 `PreviewView` 與共用的 `CardListRow` 元件，符合 **Preview Screen** 需求：依 `importOrder` 升序、有 POS 顯示 `word (pos) — translation`、無 POS 顯示 `word — translation`、底部一顆「開始測驗」按鈕導向主測驗；驗證：以包含 `apple (n.) 蘋果` 與 `look forward to 期待` 兩張卡的固定批次手動測試，畫面列分別出現 `apple (n.) — 蘋果` 與 `look forward to — 期待`，且點底部按鈕進入 QuizView。

## 7. 主測驗引擎與 UI

- [x] 7.1 在 `ReviewEngine/QuizSession.swift` 實作 design 的 **Quiz round engine with deferred re-queue** 與 spec 的 **Main Quiz Round Composition**：初始化時抽 `min(50, batch.cards.count)` 張無重複，並暴露 `currentCard`、`submit(_:)`、`isFinished`；驗證：XCTest (a) 130 張假批次 → 初始隊列長度為 50；(b) 12 張假批次 → 初始隊列長度為 12；(c) 對所有題目給正解後 `isFinished` 為 true。
- [x] 7.2 實作 `QuizView` 滿足 **Multiple Choice Question Display**：題幹顯示 word（有 POS 就加 ` (pos)`）、四個翻譯按鈕為亂序、「我不會」按鈕渲染在四選一群組之外；驗證：模擬器手動測試 `apple (n.)` 與 `look forward to` 兩題，UI snapshot 比對題幹文字與按鈕配置；另以 100 次重渲染統計，四選一順序至少出現 2 種以上排列以證實有 shuffle。
- [x] 7.3 在 QuizSession 內實作 design 的 **Distractor selection** 與 spec 的 **Distractor Selection**：同批優先抽 3 張且不等於正解，不足時跨批補；驗證：XCTest (a) 50 張獨特翻譯批次跑 100 次抽題，每次干擾皆屬同批且皆不等於正解；(b) 3 張批次跑 100 次抽題，每題含 2 張同批 + 1 張跨批干擾。
- [x] 7.4 在 QuizSession 實作 **Wrong Answer Re-Queue With Gap**：答錯或「我不會」會呼叫 `recordWrong()`（wrongCount += 1）、暴露正解、把卡片塞回 `min(remaining.count, 3)` 位置；驗證：XCTest (a) `[A,B,C,D,E,F]` 中把 A 答錯 → 隊列為 `[B,C,D,A,E,F]` 且 A.wrongCount 增 1；(b) `[A,B]` 答錯 A → 隊列為 `[B,A]`；(c) 「我不會」與選錯翻譯走相同分支。

## 8. 成績與錯題流程

- [x] 8.1 實作 `ResultView` 滿足 **Result Screen** 需求：顯示 `correct`（本輪首次嘗試即答對的卡數）與 `wrong`（本輪所有錯誤點擊次數含「我不會」），`wrong > 0` 才渲染「看錯題」按鈕；驗證：模擬器手動跑兩個劇本，全對 50 題 → 顯示 50/0 且無「看錯題」按鈕；4 張卡共 7 次錯誤 → 顯示 46/7 且按鈕出現。
- [x] 8.2 實作 `MistakeReviewView` 滿足 **Mistake Review List**：列出本輪錯題集（依 importOrder 升序），重用 `CardListRow` 元件，底部「開始錯題複習」按鈕；驗證：固定劇本（importOrder 為 3、12、17、29 的四張卡有錯）下手動測試，畫面只列這四列且順序為 3、12、17、29。
- [x] 8.3 在 `ReviewEngine/MistakeQuizSession.swift` 用相同引擎跑錯題集，落實 design 的 **Mistake quiz reuses the same engine** 與 spec 的 **Mistake Quiz Loop**：結束 Result 仍有錯就提供下一輪錯題複習入口、wrongCount 持續累加、任一 Result 都可離開回 Batch Home；驗證：XCTest (a) 4 張錯題集第一輪每張各答錯 1 次 → 第二輪錯題集仍是 4 張且每張 wrongCount 加 1；(b) 第二輪全對 → Result 不再顯示「再來一輪」入口；模擬器手動驗證離開鈕可回 Batch Home。

## 9. 端到端驗收

- [x] 9.1 依 design.md 的 Acceptance criteria 跑五項端到端驗收，並用 XCTest + 模擬器手動互補完成：(a) 130 行匯入空 deck → 批次 50/50/30；(b) 再匯入 60 行 → 出現 50/10 且原第三批仍是 30 張；(c) 解析 4 行 example 字串得到 3 個 card + 1 個 `ParseError(line=4)`；(d) 全對的 50 題 round 結束時 Result 顯示 50/0；(e) 前 3 題答錯其餘答對 → 每張重出之前隔至少 3 題，最終全對才結束；驗證：五點全部可在自動化測試或模擬器重現，並把結果記錄在 `tasks.md` 對應 checkbox 完成註記中。
