## Context

本專案從空 repo 起步。沒有既有的 iOS 程式碼、沒有共用型別、沒有任何儲存層。使用者背 TOEIC 單字，希望用 markdown 大量匯入單字，並要求 app 強制以 50 張為一個學習單位、把每張卡的錯誤次數呈現出來，並跑完整的「預習 → 測驗 → 錯題複習」迴圈。

以下所有設計決定都是這份 codebase 的第一次選擇。MVP 出貨後，使用者會直接在 Xcode 裡迭代。

## Goals / Non-Goals

**Goals:**

- 可在 Xcode 內編譯的原生 iOS app（不引入跨平台 runtime）。
- 純本機儲存，重啟後資料仍在，且支援 Deck → Batch → Card 之間的關聯。
- 一次匯入大量 markdown 後，分批結果是可預期、可重現的。
- 測驗單輪邏輯保證所有抽到的卡片都至少被答對一次後才結束。
- 錯誤次數跨輪持續累計，答對不會抵減。

**Non-Goals:**

- 不做 spaced-repetition（SM-2 / Anki 風格）排程。`wrong_count` 欄位有記錄，但 MVP 不會用它影響出題順序。
- 不做雲端同步、跨裝置同步、帳號系統。
- MVP 不做卡片編輯、deck 改名、batch 改名 UI。
- 不做超過「每輪 Result 畫面」之外的統計儀表。
- 不做 Anki / CSV / 圖片匯入。只支援下面定義的 pipe 分隔 markdown 格式。
- 不向下相容 iOS 17 以前的版本（SwiftData 需要 iOS 17+，加上專案是新的，沒有需要保留的安裝基數）。

## Decisions

### SwiftData for persistence

採用 SwiftData 做為持久化層，`Deck`、`Batch`、`Card` 都是 `@Model` 類別。考慮過的替代方案：

- Core Data：成熟但 API 老派、樣板程式碼多；在 greenfield 專案上不值得。
- 純 JSON 檔：需要手刻 CRUD、查詢、遷移；資料是關聯式的（Deck 多個 Batch、Batch 多個 Card），完全不適合。

SwiftData 勝出的理由：跟 SwiftUI 整合最好（`@Query` 會自動 re-render UI）、schema 是宣告式的（model 跟一般 Swift 類別寫法接近）、底層其實還是 Core Data，未來真要逃生到 Core Data 也容易。

### Deck → Batch → Card data shape

三個 SwiftData model，關聯與擁有關係如下：

- `Deck` 擁有多個 `Batch`（cascade delete）。
- `Batch` 擁有多個 `Card`（cascade delete），並有 `index`（在 deck 內 1-based 的序號）。
- `Card` 紀錄 `word: String`、`partOfSpeech: String?`（片語為 nil）、`translation: String`、`wrongCount: Int`、`importOrder: Int`（在所屬 batch 內的絕對位置）。

`wrongCount` 是該卡片這輩子被答錯的總次數（選錯翻譯或按「我不會」），永不下降。

### Automatic 50-card batching with immutable trailing batch

當匯入 N 張卡到一個 deck 時，parser 會把有序清單交給持久層。持久層接著：

1. 找出該 deck 目前最後一個 batch（若有）。
2. 將最後一個 batch 視為**凍結**——即使它只裝了 30 張，也不會回頭補滿。
3. 把新卡片每 50 張切成一段（最後一段可以少於 50），每段建立一個 `Batch`，`index` 接續原本的最大值。

理由：回填會更動既有 batch 的內容，並讓使用者既有的 wrong_count 統計失去意義。使用者在 discuss 階段明確選擇了「簡單」優先於「批次大小一致」。

### Pipe-delimited markdown parser

Parser 接受 UTF-8 文字。每一行非空、非純空白的行就是一張卡。以 `|` 切欄，每格 trim 前後空白。

- 3 格 → `word | partOfSpeech | translation`。中間格為空 → `partOfSpeech = nil`。
- 2 格 → `word | translation`（無詞性）。
- 其他格數 → 這行視為錯誤，回報行號與原始內容給匯入 UI，其餘行繼續匯入。

考慮過的替代方案：完整 markdown 表格解析（header row + body rows）。否決，因為它增加打字成本卻沒有行為上的好處，而且讓部分失敗的回報變複雜。

### Quiz round engine with deferred re-queue

測驗單輪維護一個有序的「remaining」佇列。每一 tick：

1. 從佇列頭取出一張顯示。
2. 使用者選正確翻譯：把這張從佇列移除。
3. 使用者選錯誤翻譯 **或** 按「我不會」：把該卡 `wrongCount` + 1（立即持久化）、顯示正解、把該卡塞回佇列中 `min(remaining.count, gap)` 的位置（離頭部 `gap` 位），其中 `gap = 3`。這樣保證至少間隔 3 張（若剩餘不足 3 張就全部當間隔）才會再出現。
4. 佇列空了，這輪結束。

選 `gap = 3` 的理由：夠大讓使用者不能直接默背剛剛揭示的答案；夠小讓快結束時的佇列還能順利收尾。

否決的替代方案：

- 塞回佇列的隨機位置：讓一輪題目數變不可預期，也難寫測試。
- 馬上又問同一張：等於直接洩答案。

### Distractor selection

對 batch `B` 內 card `C` 出題時，三個干擾選項從 `B.cards` 中隨機抽，條件是該卡不為 `C` 且翻譯不等於 `C.translation`（避免重複正解的同義字）。若 `B` 內可用干擾翻譯不足 3 個（非常小的 batch），就跨 batch 從同 deck 補齊。最終 4 個選項（正解 + 3 個干擾）在顯示前會隨機洗牌。

「我不會」按鈕是第五顆獨立控制元件，渲染在四選一下方，不會被洗進選項陣列裡。

### Mistake quiz reuses the same engine

錯題測驗就是用本輪錯題集當輸入去建立的 `QuizSession`，不是重新抽 50 張。干擾選項仍從整個 batch 抽（同演算法），這樣選項池才不會塌縮成「只在你剛剛錯的那幾張間二選一」。結束後若仍有錯，可以再啟動一輪基於新錯題集的錯題測驗；可循環直到使用者退出或某輪全對。

### Xcode project layout

單一 SwiftUI app target，名稱 `VocTest`。`VocTest/` 下面的資料夾：`Models/`（SwiftData @Model 類別）、`Parser/`（markdown 解析，純函式）、`ReviewEngine/`（測驗 session 狀態機，純邏輯）、`Views/`（SwiftUI 畫面與輕量 view-model 黏合）。純邏輯資料夾不能 import SwiftUI、純資料資料夾不能寫 view 程式碼。這樣 parser 與測驗引擎都可以不啟動 SwiftUI 就單元測試。

## Implementation Contract

**Observable behavior:**

- 啟動 app 看到 Deck 清單。沒有 deck 時，使用者可以按「+」建立一個叫「TOEIC 常考」的 deck（或其他自訂名稱）。
- 點 deck 進入 Batch 清單。每列顯示 batch index、卡數、該 batch cards 的 `wrongCount` 累計。
- 點 batch 進入「批次首頁」，上面兩顆按鈕：「先複習所有單字」與「直接開始測驗」。
- 預習畫面以 `importOrder` 升序顯示該 batch 全部卡片的可滾動清單；有 POS 時格式為 `word (pos) — translation`，否則為 `word — translation`。最底下有「開始測驗」按鈕進入主測驗。
- 測驗一次顯示一題：題幹（有 POS 就附在括號裡）、四個翻譯按鈕、一顆「我不會」按鈕。點任何答案後會先顯示正解再進下一題。
- 一輪結束時 Result 畫面顯示本輪的 `correctCount`（本輪一次就答對的卡片數）與 `wrongCount`（本輪所有錯誤點擊次數，含「我不會」點擊，**不是**每張卡的累計總數）。若本輪有錯，會出現「看錯題」按鈕，進入錯題清單，再進入由那些卡組成的錯題測驗。

**Data contract:**

- `Card.wrongCount` 每次錯誤點擊或「我不會」點擊正好加 1，錯題測驗中發生的點擊也算。答對絕不修改它。
- `Batch` 建立後尺寸不可變；匯入器永不向既有 batch 追加或刪減卡片。

**Markdown parser contract:**

- 輸入：單一 UTF-8 字串。輸出：`(Array<ParsedCard>, Array<ParseError>)`，其中 `ParsedCard` 有 `word`、`partOfSpeech: String?`、`translation`；`ParseError` 有 `lineNumber`（1-based）與 `rawLine`。
- 空白行與純空白行靜默跳過。
- Pipe 數 = 1 → 兩欄解析；pipe 數 = 2 → 三欄解析；其他數 → 回 ParseError。

**Quiz engine contract:**

- `QuizSession` 對外暴露 `currentCard: Card?`、`submit(answer: Choice) -> AnswerResult`（其中 `Choice` 為 `.translation(String)` 或 `.dontKnow`）、`isFinished: Bool`。引擎相對於輸入是純的（它不持有 SwiftUI 狀態），可單元測試。
- `submit` 之後若答錯，引擎會把該卡塞回佇列頭部往後 `min(remaining.count, 3)` 的位置。

**Acceptance criteria:**

- 對空 deck 匯入 130 行有效 markdown，會產生三個 batch，大小依 index 順序為 50、50、30。再對同 deck 匯入 60 行，會再產生兩個 batch，大小為 50、10——原本的 30 卡 batch 不被觸碰。
- 解析 `apple | n. | 蘋果`、`look forward to | 期待`、`look forward to | | 期待`、以及 `bad line with four | | | cells` 會得到 3 張成功卡片 + 1 個第 4 行的 ParseError。
- 一輪測驗每題都首次答對，最終題數正好為 `min(50, batch.cards.count)`。
- 一輪測驗使用者前 3 題都答錯、之後全對，這 3 張會重新出現，每次重出之前至少間隔 3 題，且最終 3 張都答對才結束。
- 點「我不會」會讓 `wrongCount` + 1，並在引擎計帳上與選錯翻譯無法區分。

**In scope:**

Deck / Batch / Card 模型、SwiftData store wiring、markdown parser（含 app 內貼上文字框與 Files-app 檔案選擇器兩條路徑）、分批規則、預習畫面、主測驗、Result 畫面、錯題清單、可循環的錯題測驗。

**Out of scope:**

Spaced repetition、卡片編輯、deck / batch 改名、雲端同步、超過每輪 Result 之外的統計儀表、非 markdown 的匯入格式。

## Risks / Trade-offs

- [SwiftData 在 iOS 17 有已知的 migration 怪癖] → MVP 只出單一 schema 版本。後續 schema 變動時加上版本化的 `SchemaMigrationPlan`。
- [極小批次時干擾選項池會塌縮] → fallback 改抽同 deck 其他 batch 的翻譯。若整個 deck 翻譯少於 4 種，UI 就顯示能抽到的（這是 deck 顯然太空的可接受邊界情況）。
- [使用者重複匯入同一個字] → 不做去重。兩列各自成卡片，可能在同 batch 或不同 batch。屬於已知行為；若實際造成困擾再修。
- [Files-app 檔案選擇器需要 Info.plist document-type 條目] → 實作必須把 `.md` 與 `.txt` 註冊為可讀型別，否則選擇器會靜默把它們過濾掉。
- [discuss 對話以繁體中文進行] → UI 文案（按鈕、錯誤訊息、畫面標題）用繁體中文出貨。**程式碼識別字、檔名、以及 `specs/*/spec.md` 規格檔仍維持英文**（spec 使用 SHALL/MUST 規範語言，analyzer 強制英文），其餘 Spectra artifacts（proposal、design、tasks）跟著專案 locale 用繁體中文。
