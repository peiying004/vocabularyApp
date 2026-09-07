## Context

App 目前入口是 `ContentView` 包一個 `NavigationStack { DeckListView() }`，DeckListView 是 App 唯一 landing。單字流程走 Deck → Batch → Card；分批以 50 為單位；四選一測驗的干擾選項從 batch 內其他卡片的 `translation` 隨機抽（`QuizSession.pickDistractors`）；答對即時前進、答錯記 `wrongCount` 並塞回佇列。整條單字 stack 剛剛穩定並 archive 完成，任何對它的改動都有回歸風險。

使用者希望在同一個 App 內新增文法填空題（例如「I ___ to school every day.」四選一 go/goes/going/gone），並以 Apple Health 風格 icon 按鈕的兩鍵首頁作為新的 App shell。文法填空題的干擾選項本質上必須手動編寫（相同動詞的其他變形，無法用「同 batch 其他題正解」抽），這是跟單字題最本質的差異。使用者同時明確要求「單字功能完全不動」。

## Goals / Non-Goals

**Goals:**

- 讓 App 打開後看到一個具備兩顆大按鈕的首頁（Apple Health 風格 icon + 標題），單字入口導向現有畫面、文法入口導向全新平行 stack。
- 文法題支援 GFM markdown 5 欄匯入格式（`| question | correct | distractors_csv | explanation |`），distractors 為手動指定的三個字串。
- 文法題測驗流程對齊單字題的「四選一 + 我不會 + 答錯重排 + 一輪需全對通過 + 錯題複習」，但選項來源改為 item 自帶。
- 文法題測驗答完不論對錯，若題目提供 explanation，都會顯示。
- 提供 10 題示範資料檔案，讓使用者 build 完 App 立即有題目可玩。
- 單字整條 code（Models / Parser / ReviewEngine / Views / Tests）零改動，零回歸風險。

**Non-Goals:**

- 不做「共用 Deck/Batch/Card 加型別欄」的路線（見 Alternatives Considered），避免動到單字。
- 不支援輸入型答案（如 sentence transformation 之類）、找錯題（B/C/D 選項為完整句子的其他題型）、翻譯配對；本次僅支援填空題。
- 不新增依題型自動生成 distractors 的功能，distractors 完全由題目作者提供。
- 不動既有的 `flashcard-deck` 分批規則、`Card` 欄位、`QuizSession` 演算法，僅修改該 spec 中描述「App 頂層導覽」的那一項需求。
- 不做首頁的統計儀表板、設定頁、匯出備份等額外功能；本次首頁只有「單字」「文法」兩顆按鈕。
- 不改變單字題的匯入格式（既有 pipe / GFM 5 欄格式 `word | pos | translation` 保留）。

## Decisions

### Home shell 採 Apple Health 風格兩鍵 root

`ContentView` 的 body 從 `NavigationStack { DeckListView() }` 改為 `NavigationStack { HomeView() }`。`HomeView` 內兩個垂直排列的大 icon 按鈕：上方單字（icon `character.book.closed`，標題「單字」，副標「四選一翻譯測驗」），下方文法（icon `text.book.closed`，標題「文法」，副標「填空四選一」）。每顆按鈕是 `NavigationLink { destination } label: { HomeButtonLabel(...) }`，destination 分別是既有的 `DeckListView()` 與新增的 `GrammarDeckListView()`。

不採 TabView：TabView 會固定佔用畫面底部空間、視覺重心分散；當日的實驗與早期功能形態較適合 push-nav 進去。

**Alternatives considered:**

- 「TabView 底部標籤」：拒絕。想保留 iOS 標準的階層導覽感、且 App 未來若加更多題型，push-nav 比 tab 好擴充（只要 HomeView 多一顆按鈕）。
- 「單字放頂部作為主功能，文法藏在漢堡選單」：拒絕。使用者明確要求兩者平等入口。

### Grammar 走 parallel 架構

新增全套 `GrammarDeck / GrammarBatch / GrammarItem` 模型與 `GrammarDeckListView / GrammarBatchListView / GrammarBatchHomeView / GrammarPreviewView / GrammarQuizView / GrammarResultView / GrammarMistakeReviewView / GrammarImportView / GrammarItemRow` 一整套 View；session 引擎新增 `GrammarQuizSession` 與 `GrammarMistakeQuizSession`。所有既有 Card / Batch / Deck / QuizSession / MistakeQuizSession / DeckListView / ... 檔案零改動。

**Alternatives considered:**

- 「共用 Card + 加 kind 型別欄」：拒絕。會讓 Card 塞入 distractors / explanation 等對單字無意義的欄位；QuizSession.pickDistractors 要在 runtime 分岔；既有 view 都要判 kind，觸及範圍大且高風險。
- 「將 QuizSession 泛化為協定，讓兩個題型都實作」：延後。這種抽象化在只有兩種題型時價值不高，等未來出現第三種題型再考慮。目前接受兩個 session 檔案有 ~60 行重複邏輯（`remaining` 佇列管理、`recordWrong` 呼叫、`isFinished` 判定）。

### GrammarItem 資料模型

`GrammarItem` 是 SwiftData `@Model` class，欄位：
- `question: String`（非空）
- `correct: String`（非空）
- `distractors: [String]`（三個非空字串，長度剛好 3）
- `explanation: String?`（可空，空字串視為 nil）
- `wrongCount: Int`（預設 0，單調遞增）
- `importOrder: Int`（0-based）
- `batch: GrammarBatch?`

SwiftData 對 `[String]` 陣列的支援直接使用（stored as transformable data）。若真的踩到 SwiftData 對陣列不支援的 edge case，備案是改用 `distractor1 / distractor2 / distractor3: String` 三個獨立欄位，這個備案不改動 UI 或 parser 邏輯，只需要在存讀時打包／拆包。

**GrammarDeck 與 GrammarBatch** 結構完全鏡像 `Deck` 與 `Batch`：Deck 有 name / createdAt / grammarBatches 陣列（cascade delete）；Batch 有 index / createdAt / deck / items 陣列（cascade delete）。

### Import format：GFM 5 欄 pipe，distractors 用逗號分隔

`GrammarMarkdownParser` 支援兩種輸入：
- 純 pipe 5 欄：`question | correct | distractor1,distractor2,distractor3 | explanation`
- GFM 表格（兩端有 pipe / 有表頭列 / 有分隔線），與現有 `MarkdownParser` 一樣的 boundary 剝除、header 跳過、separator 跳過邏輯（keyword 集擴充為 grammar-friendly：question 欄關鍵字 `question` / `題目` / `sentence`，correct 欄關鍵字 `correct` / `answer` / `正解`）。

Parser 拿到 4 欄後：
- 若第 3 欄拆逗號後不是恰好 3 個非空字串（trim 過），該行視為 `ParseError`，不進 cards。
- 若第 4 欄為空字串（含只有空白），explanation 存為 nil。
- 其餘與 `MarkdownParser` 一致：空行跳過、欄位數不符（不是 4 欄）發 `ParseError`。

Parser 產出型別 `ParsedGrammarItem { question, correct, distractors: [String; 3], explanation: String? }`，`GrammarItemImporter` 依匯入順序自動分批，規則等同 `CardImporter`，且批次大小與單字側同值（見下方決策）。

**Alternatives considered:**

- 「distractors 一欄一個（六欄 pipe）」：拒絕（討論階段 option 3）。使用者選擇 5 欄，逗號分隔可讀性優先。
- 「JSON / YAML 匯入」：拒絕。與既有單字匯入慣性斷裂、Parser 過度工程。

### Distractor 來源：item 自帶，不再取自 batch

`GrammarQuizSession.choicesForCurrent()` 回傳將 `currentItem.correct` 與 `currentItem.distractors` 三個字串合成的四個字串（用固定 `shuffled()` 打亂順序）。不呼叫任何 batch-scan 邏輯、不參考其他 item 的欄位。

`submit(_ choice:)` 沿用單字題的機制：答對即移除 `remaining` 首項；答錯則 `recordWrong` + wrongTapCount+1 + 首項移除後 insert at `min(remaining.count, 3)`。`resultSummary()`、`isFinished`、`mistakeCardIDs` 等對外介面與 `QuizSession` 保持一致（型別為 `GrammarItem`）。

### Explanation 顯示時機：永遠

`GrammarQuizView` 的 feedback banner 邏輯：
- 答對：顯示綠色「答對」+（若 explanation 有值）灰色副標一行顯示 explanation。
- 答錯或按「我不會」：顯示紅色「正解：{correct}」+（若 explanation 有值）灰色副標一行顯示 explanation。

`GrammarPreviewView`（預習畫面）在每個 item 的 row 內也顯示 explanation（若有），讓使用者一次瀏覽整批。

**Alternatives considered:**

- 「只在答錯時顯示 explanation」：拒絕。使用者明確要求答對也要看到（強化正確答案的原理）。
- 「optional 讓使用者切換顯示」：拒絕。首版避免設定頁，keep it simple。

### Batch 大小：20

`GrammarItemImporter.chunkSize` 與 `CardImporter.chunkSize` 同值（目前 40）。原先曾讓文法採較小的 20 題，理由是文法題認知負擔重；後續統一為單一數字，讓使用者只需記住一個「一批多少」，兩側的常數也因此不會各自漂移。批次大小是可調的單一常數，測驗抽題與手動新增上限都由它推導。

### 示範資料

新增 `voc/文法練習-基礎 unit1.md`，10 題涵蓋：主動詞一致（3rd person singular）、不規則過去式、modal verbs、介系詞（時間 on）、現在完成式、第一類條件句、被動語態未來式、比較級（多音節 more）、as...as 句型。每題附中文 explanation。首行為 YAML front matter（`title` / `tags`），中間有 `# 標題` 與 `## unit 1`；parser 應把這些非資料列列為 `ParseError`（等同單字 flow 的體驗）。

## Implementation Contract

**Behavior:**

- App 打開後看到首頁 `HomeView`：兩顆並列的大按鈕，樣式模仿 Apple Health 的「My Highlights / Sharing」風格（顏色塊 + 大 icon + 主標 + 副標）。點單字進入既有 `DeckListView`（現有行為完整保留）。點文法進入 `GrammarDeckListView`。
- 文法側任一 Deck 內可以匯入 GFM 5 欄或純 pipe 5 欄的 markdown，`ImportResult.itemsAdded` 精確等於 parser 成功產出的卡片數，被跳過的表頭 / 分隔線不計入錯誤。
- 文法測驗每輪抽該 batch 最多一個批次量的題數，預設取自共用批次大小常數（batch 未滿就全部考），四選一 + 我不會，答完題目留在原題（同單字現在的 `pendingChoice` 行為），按下一題才前進；answer banner 恆顯示 explanation（若題目有）。
- 錯題複習流程：一輪結束後看到成績摘要 + 「看錯題」按鈕（若有錯）；錯題整理畫面列出本輪錯題 + 「開始錯題複習」，錯題複習的 distractors 仍然來自 item 自帶（**不從錯題子集重抽**）；錯題可循環直到全對。
- 錯題以 `GrammarItem.wrongCount` 累計，跨測驗回合、跨 App 重啟保留；歸零僅在 App 未提供的手動重置操作發生（本次不做）。

**Interface / data shape:**

- Views：`HomeView`、`GrammarDeckListView`、`GrammarBatchListView`、`GrammarBatchHomeView`、`GrammarPreviewView`、`GrammarItemRow`、`GrammarQuizView`、`GrammarResultView`、`GrammarMistakeReviewView`、`GrammarImportView`。導覽全部使用 inline `NavigationLink { destination } label:` 樣式（避免上個 change 踩過的 `.navigationDestination(for:)` on pushed view 失效問題）。
- Models：`GrammarDeck { name, createdAt, grammarBatches: [GrammarBatch] }`、`GrammarBatch { index, createdAt, deck: GrammarDeck?, items: [GrammarItem] }`、`GrammarItem { question, correct, distractors: [String], explanation: String?, wrongCount, importOrder, batch: GrammarBatch? }`。所有 relationship 皆 cascade delete。
- Parser：`GrammarMarkdownParser.parse(_ input: String) -> (items: [ParsedGrammarItem], errors: [ParseError])`。`ParsedGrammarItem` 為結構型別，欄位如 Decisions 所述。
- Session：`GrammarQuizSession { remaining: [GrammarItem], totalItemsInRound, wrongTapCount, ... }`；公開方法 `currentItem`、`choicesForCurrent()`、`submit(_ choice: Choice)`、`resultSummary()`、`isFinished`。`Choice` enum 沿用單字的 `.translation(String) / .dontKnow`（**共用型別**——這是唯一跨型別共用的部分，因為選項本身就是字串）。
- Importer：`GrammarItemImporter.appendItems(_ parsed: [ParsedGrammarItem], to deck: GrammarDeck, in context: ModelContext)`，行為對齊 `CardImporter.appendCards` 但 `chunkSize = 20`。
- App root：`VocTestApp` 的 `.modelContainer(for:)` 追加三個新型別 `[Deck.self, Batch.self, Card.self, GrammarDeck.self, GrammarBatch.self, GrammarItem.self]`。

**Failure modes:**

- 匯入時使用者貼入的行不是 4 欄（去掉兩端 pipe 後）、或 distractors csv 拆完不是恰好 3 個非空字串、或 question / correct 任一為空 → 該行以 `ParseError { lineNumber, rawLine }` 記錄，不進資料庫，其餘行繼續處理。
- 匯入時使用者選了單字 Deck 卻走進文法匯入 UI（或反之）→ 型別不匹配編譯期就阻擋（`GrammarImportView.targetDeck: GrammarDeck?`），使用者選 Deck picker 時只列出 GrammarDeck。
- SwiftData 對 `[String]` 陣列若某版本存取失敗 → 備案改用三個字串欄位（見 GrammarItem 資料模型 decision），這個 fallback 在 tasks 中列為若碰到才做的分支任務。
- 空 GrammarBatch（0 個 item）：`GrammarBatchHomeView` 應顯示「這個批次還沒有卡片」空狀態，行為對齊單字。

**Acceptance criteria:**

- `xcodebuild test -scheme VocTest -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'` 全數綠燈，包括：
  - `GrammarMarkdownParserTests`：覆蓋 5 欄純 pipe、GFM 表格、表頭跳過、分隔線跳過、distractors 逗號分隔正確拆解、explanation 空字串處理、無效行報錯。
  - `GrammarQuizSessionTests`：四選一由 item 自帶 distractors、答錯重排（隔幾題再現）、一輪全對才 finish、wrongCount 遞增、錯題摘要正確。
  - `GrammarItemImporterTests`：依共用批次大小分批、既有 batch 不洗牌、尾端未滿 batch 保留。
  - 既有 `MarkdownParserTests` / `QuizSessionTests` / `CardImporterTests` / `AcceptanceTests` 通過且測試檔案未被修改。
- 手動驗收：build 到 iPhone → 首頁看到兩顆 Apple Health 風格按鈕 → 點單字看到現有 Deck List → 返回 → 點文法 → 建立 Deck「基礎文法」→ 貼上 `voc/文法練習-基礎 unit1.md` 完整內容 → 匯入結果顯示「新增 10 張卡、產生 1 個新批次」→ 進 batch → 測驗 → 每題答完可看到 explanation → 答錯後看錯題可正常進入錯題整理 → 開始錯題複習可正常結束回到成績畫面。

**Scope boundaries:**

- 在範圍內：所有 `VocTest/Views/Grammar*`、`VocTest/Models/Grammar*`、`VocTest/Parser/GrammarMarkdownParser.swift`、`VocTest/ReviewEngine/Grammar*Session.swift`、`VocTest/Views/HomeView.swift`、`VocTest/ContentView.swift`、`VocTest/VocTestApp.swift`（僅 model container 新增三個 model 型別）、對應測試檔、`voc/文法練習-基礎 unit1.md`、`openspec/specs/flashcard-deck/spec.md` 中「Primary Navigation Screens」需求文字調整。
- 不在範圍內：既有單字整條 stack 的任何邏輯或 UI 檔案、既有 `flashcard-deck` spec 中除了「Primary Navigation Screens」以外的其他需求、既有 `vocabulary-import` / `quiz-review` spec、既有測試檔的斷言、`voc/多益單字們- unit1.md`。

## Risks / Trade-offs

- **SwiftData `[String]` 陣列支援**：文獻與實測顯示 SwiftData 對簡單值型別陣列（含 `[String]`）在 iOS 17+ 是支援的，但如果實作時 build 或 runtime 出錯，會影響匯入與讀取。緩解：Decisions 中已列出 fallback 為三個獨立字串欄位，改動範圍不大（parser / session 不變，只有 model 欄位定義變）。
- **UI 相對重複（~7 個 view 檔案跟單字對應）**：Parallel 架構下每個文法 view 都是單字對應 view 的鏡像實作。若未來需要在兩邊同步微調（例如統一色彩、字型），得改兩處。緩解：檔案結構、命名、函式簽章保持一致，diff 好對照；未來若真的成為維護負擔再抽共用元件。
- **HomeView 沒進 `flashcard-deck` capability，另起 `app-home`**：可能被誤讀為「小事情不值得獨立 capability」。但因為 home shell 是跨型別的（同時服務單字與文法），塞進 flashcard-deck 語意錯誤，另起獨立 capability 較乾淨。
- **示範資料檔命名有全形空格**：`voc/文法練習-基礎 unit1.md` 中間有中文空白。既有 `voc/多益單字們- unit1.md` 也有類似情況，parser 對檔案路徑無感（讀進來的內容才重要），這裡命名對齊既有慣例。
- **與剛完工的 QuizView 一連串修正的知識轉移**：`GrammarQuizView` 必須從一開始就套用「pendingChoice 延後 submit」、「答完停在原題直到按下一題」、「不用 `.navigationDestination(item:)` 而用 inline 條件顯示 ResultView」這三個踩過的坑。緩解：Tasks 明確要求 GrammarQuizView 對齊當前 `QuizView` 的行為契約，並在測試中包含「答題後題目留在原本 item」的斷言。
