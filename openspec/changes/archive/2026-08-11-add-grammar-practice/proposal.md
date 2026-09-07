## Why

使用者已完成 40 張單字卡的匯入與測驗流程，App 現在只支援單字題型（`word | pos | translation`）。為了讓同一個 App 同時涵蓋 TOEIC 常見的另一個大類——文法填空題（例如「I ___ to school every day.」搭配 go / goes / going / gone 四選一），需要新增獨立的資料模型、匯入格式、測驗引擎與導覽 stack。因為單字剛完工且穩定，變更目標是「單字整條完全不動」，文法走一套平行的新 stack；App 入口從單一 `DeckListView` 改成 Apple Health 風格的兩顆大 icon 按鈕（單字／文法）作為 shell。

## What Changes

- 新增首頁 shell：兩顆 Apple Health 風格大按鈕（icon + 文字），一顆進單字（現有 `DeckListView`），一顆進文法（新的 `GrammarDeckListView`）。
- 新增文法資料模型：`GrammarDeck` → `GrammarBatch` → `GrammarItem`，`GrammarItem` 欄位為 question / correct / distractors（3 個字串）/ explanation（可空）/ wrongCount / importOrder。
- 新增文法匯入格式：GFM pipe 5 欄 `| question | correct | distractors_csv | explanation |`，distractors 以逗號分隔（作者手寫、不從其他題自動抽）；complet parser 繼承既有 boundary/header/separator 判定規則。
- 新增文法測驗引擎 `GrammarQuizSession`：四選一 + 「我不會」 + 答錯重排 + 一輪需全對通過的同一套機制，但**四個選項來自 item 自帶的 correct + distractors**（不再從 batch 其他 item 隨機抽）。
- 新增文法測驗 UI：答完（答對或答錯皆同）**永遠**顯示 correct 的 explanation（若題目有提供），banner 底下加一行副標。
- 新增完整文法用 View 家族：DeckList / BatchList / BatchHome / Preview / Quiz / Result / MistakeReview / Import，行為對齊單字（分批、預習、錯題複習等）。
- 每 batch 的題數取自專案共用的批次大小常數（目前 40），與單字側同值。
- 新增示範資料檔：`voc/文法練習-基礎 unit1.md`，內含 10 題 TOEIC 級文法題（主動詞一致、不規則過去式、modal、介系詞、現在完成式、條件句、被動、比較級、as...as 句型）。
- 修改 `flashcard-deck` 的「Primary Navigation Screens」需求：Deck List 從「app 根畫面」改為「首頁單字按鈕進入的目的地」，其餘（Batch List / Batch Home）不變。
- 單字整條 stack（Card / Batch / Deck / QuizSession / MistakeQuizSession / DeckListView / BatchListView / BatchHomeView / PreviewView / QuizView / ResultView / MistakeReviewView / ImportView / MarkdownParser / CardImporter）**完全不改**。

## Capabilities

### New Capabilities

- `app-home`：新的 App 根導覽 shell，提供單字 / 文法兩個入口，取代原本直達 Deck List 的行為。
- `grammar-deck`：文法用的 GrammarDeck / GrammarBatch / GrammarItem 資料模型、SwiftData 持久化、以及文法側的 Deck 清單、Batch 清單、Batch Home 導覽。
- `grammar-import`：文法用的 5 欄 pipe（含 GFM 表格容忍）markdown 匯入 parser、沿用共用批次大小的自動分批規則，以及對應的貼上／檔案匯入 UI。
- `grammar-review`：文法測驗引擎（item 自帶 distractors 的四選一 + 我不會 + 答錯重排 + explanation 永遠顯示 + 錯題複習）、預習畫面、成績畫面。

### Modified Capabilities

- `flashcard-deck`：修改「Primary Navigation Screens」需求，說明 Deck List 從 App 首頁的「單字」按鈕進入，而不再是 App 根畫面本身；`Deck-Batch-Card Hierarchy`、`Card Fields`、`Wrong Count Is Monotonic`、`Automatic Batching` 等其他需求不變。

## Impact

- Affected specs：`app-home`（new）、`grammar-deck`（new）、`grammar-import`（new）、`grammar-review`（new）、`flashcard-deck`（modified）
- Affected code：
  - New: VocTest/Views/HomeView.swift
  - New: VocTest/Models/GrammarDeck.swift
  - New: VocTest/Models/GrammarBatch.swift
  - New: VocTest/Models/GrammarItem.swift
  - New: VocTest/Models/GrammarItemImporter.swift
  - New: VocTest/Parser/GrammarMarkdownParser.swift
  - New: VocTest/ReviewEngine/GrammarQuizSession.swift
  - New: VocTest/ReviewEngine/GrammarMistakeQuizSession.swift
  - New: VocTest/Views/GrammarDeckListView.swift
  - New: VocTest/Views/GrammarBatchListView.swift
  - New: VocTest/Views/GrammarBatchHomeView.swift
  - New: VocTest/Views/GrammarPreviewView.swift
  - New: VocTest/Views/GrammarQuizView.swift
  - New: VocTest/Views/GrammarResultView.swift
  - New: VocTest/Views/GrammarMistakeReviewView.swift
  - New: VocTest/Views/GrammarImportView.swift
  - New: VocTest/Views/GrammarItemRow.swift
  - New: VocTestTests/GrammarMarkdownParserTests.swift
  - New: VocTestTests/GrammarQuizSessionTests.swift
  - New: VocTestTests/GrammarItemImporterTests.swift
  - New: voc/文法練習-基礎 unit1.md
  - Modified: VocTest/ContentView.swift
  - Modified: VocTest/VocTestApp.swift
  - Modified: openspec/specs/flashcard-deck/spec.md
  - Removed: (none)
