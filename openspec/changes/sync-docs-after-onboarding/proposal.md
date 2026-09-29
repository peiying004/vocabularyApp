## Summary

把 README 與 docs/ 三份說明文件同步到 onboarding 教學加入之後的程式現況：補上教學相關敘述、修正三處與程式行為相反的說法，並更新 architecture.md 的 mermaid 架構圖與操作流程圖，另在 README 放精簡版的兩張圖。

## Motivation

最近一次 commit「新增 app 功能導覽畫面」加入了首次啟動教學（ContentView 的 overlay、OnboardingOverlayView、OnboardingPage、OnboardingIllustrations、HomeView 的重看按鈕），但 README、docs/architecture.md、docs/getting-started.md、docs/implementation.md 都沒有跟著更新。同時文件裡累積了三處與程式碼相反、會誤導讀者的敘述：

1. README 與 getting-started 宣稱「自動略過 YAML front-matter」，但 MarkdownParser 與 GrammarMarkdownParser 會把沒有 `|` 的 `---`、`title:` 等行回報為 ParseError 並在畫面列為無效行。vocabulary-import spec 與 MarkdownParserTests 的 testDashOnlyLineWithoutPipeIsNotSeparator 都鎖住這個行為，所以是文件錯、不是程式錯。
2. README「自動切批」bullet 說「批次滿了就不能再加，不會自動溢位到別批或另開新批」，但同一份 README 下方兩個 bullet 與 PreviewView、BatchImportView 都允許使用者在批次已滿或貼上超量時選擇「開新批次」。這句是 batch-markdown-import 之前的舊敘述。
3. architecture.md 操作流程圖把結果頁的「完成」畫成回到分組列表，但 ResultView 的「回到批次首頁」按鈕是 dismiss()，會回到推入測驗的那一頁（批次首頁或預習清單）；結果頁與錯題複習之間也漏了 MistakeReviewView 的錯題整理清單。

這份專案的 README 明言是作品展示用途，文件與程式不一致會直接削弱說服力，且教學功能是目前最新、最值得被看到的改動。

## Proposed Solution

只修文件，不動程式、測試與既有的 11 個功能 spec。

- **docs/architecture.md**
  - 分層架構圖加上「App 殼層」子圖：ContentView、OnboardingOverlayView、UserDefaults 的 hasSeenOnboarding 旗標，箭頭連到 HomeView，並標示旗標不在 SwiftData Model 層。
  - 操作流程圖拆成兩張：主流程圖加入教學判斷、首頁重看教學、批次首頁的兩個入口、錯題整理清單、結果頁正確的回退目標；內容管理流程圖涵蓋預習清單的點列編輯、＋選單、批次已滿提示、貼上超量選擇，並合併既有的編輯模式多選刪除圖。
  - 專案結構樹補上 ContentView.swift、VocTestApp.swift、三個 Onboarding 檔、MistakeReviewView 與 GrammarMistakeReviewView。
  - 設計取捨新增一條：教學已看過旗標存 UserDefaults 而非以資料庫是否為空判斷，避免使用者刪光內容後教學再跳出。
- **README.md**
  - 功能總覽新增「首次啟動教學，首頁右上角可重看」。
  - 「自動切批」bullet 刪除「不會另開新批」敘述，改為需經使用者同意才開新批次。
  - 「容錯解析」bullet 把「自動略過 YAML front-matter」改為「front-matter 等非表格行會列為無效行並跳過，不影響其餘匯入」。
  - 「四選一測驗」bullet 註明干擾選項抽取只適用單字路線，文法題使用題目自帶選項。
  - 文件導覽之後新增「架構與流程一覽」小節，放一張不超過 10 個節點的精簡架構圖與一張不超過 10 個節點的精簡主流程圖，並連結到 docs/architecture.md 看完整版。
- **docs/getting-started.md**
  - 匯入格式段落的 front-matter 敘述同步修正。
  - 首次使用步驟加入「首次啟動先看到 4 頁教學，按開始使用或右上角 X 關閉」，並把「點任一批次即可開始測驗」改為「點批次進入批次首頁，選先複習或直接開始測驗」。
- **docs/implementation.md**
  - 測驗狀態機圖的「不知道」改為按鈕實際文字「我不會」。
  - 第 2 節解析器範例的 2 欄分支補上 word 與 translation 的非空 guard，並加註範例省略了空白行、分隔列、表頭列的略過邏輯。
  - 測試涵蓋範圍補上 OnboardingTests 與 AcceptanceTests。

## Alternatives Considered

- **讓程式真的略過 YAML front-matter，以符合文件**：被否決。spec 與測試已明文規定無 `|` 的 `---` 不是分隔列，改程式屬於功能變更，需另開 change 走 propose，不在文件同步範圍。
- **只在 README 放圖、不改 architecture.md**：被否決。architecture.md 已有完整版的圖，讀者會先看到過時的版本；README 放精簡版是為了第一次看的人，不取代完整版。
- **把兩條流程畫在同一張圖**：被否決。內容管理有四條分支加多選刪除，合在主流程會超過 25 個節點，失去可讀性。

## Capabilities

### New Capabilities

- `project-documentation`: 對外說明文件（README 與 docs/）必須涵蓋的內容與必須與程式一致的敘述，包含 mermaid 架構圖、使用者流程圖、教學功能說明，以及 front-matter、批次溢出、測驗回退目標的正確描述。把文件當成可驗證的交付物，之後任何功能 change 都能對照此 spec 檢查文件是否漏更新。

### Modified Capabilities

無。既有 11 個功能 spec 的需求不變。

## Impact

- Affected specs: 新增 project-documentation；不修改任何既有 spec。
- Affected code:
  - Modified:
    - README.md
    - docs/architecture.md
    - docs/getting-started.md
    - docs/implementation.md
  - New: 無
  - Removed: 無
