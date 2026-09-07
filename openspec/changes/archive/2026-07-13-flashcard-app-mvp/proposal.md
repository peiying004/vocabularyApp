## Why

使用者想在 iOS 上背 TOEIC 單字，需要一個支援大量 markdown 匯入、自動把每 50 個單字切成一個學習單位、並提供完整「測驗 → 錯題複習」迴圈且能追蹤每張卡片錯誤次數的單字卡 app。本專案目前是空的——沒有可延伸的既有功能。

## What Changes

- 全新原生 iOS app（Swift + SwiftUI），最低支援 iOS 17，可用 Xcode 開啟。
- 以 SwiftData 做持久化儲存。
- 用 pipe（`|`）分隔的 markdown 格式批次匯入單字：
  - 三欄：`word | pos | translation`
  - 兩欄（無詞性，例如片語）：`phrase | translation`
  - 三欄但中間留空也接受：`phrase | | translation`
- 兩個匯入入口：app 內的貼上文字框、以及從 iOS 檔案 app 選取 `.md` / `.txt` 檔。
- 資料模型：Deck → Batch → Card。每張 Card 紀錄單字、可選的詞性、翻譯、累計錯誤次數。
- 自動分批：匯入一批單字到一個 deck 時，新卡片依匯入順序每 50 張切成一個 batch。**既有 batch 不會被洗牌或補滿**——尾端若有一個未滿 50 張的 batch，會維持原本大小，新卡片從下一個 batch 邊界開始。
- 每個 batch 的「批次首頁」有兩個動作入口：
  - 預習：依匯入順序顯示這個 batch 內所有卡片（單字、詞性如有、翻譯）的可滾動清單，唯讀。
  - 直接開始測驗：跳過預習，直接啟動主測驗。
- 主測驗機制：
  - 從 batch 內隨機抽最多 50 張（batch 不到 50 張就全部考）。
  - 每題顯示單字（有詞性時以括號附在後面，例如 `apple (n.)`），下方為四個中文翻譯選項，再加上獨立的第五顆「我不會」按鈕。
  - 三個干擾選項從同 batch 其他卡片的翻譯隨機抽。
  - 答錯或按「我不會」：該卡的 wrong_count + 1、顯示正解、然後把該卡塞回剩餘題目佇列中，**間隔幾題後才會再出現**（不會是下一題）。
  - 一輪只有當所有抽到的卡片至少都答對過一次才結束。
- 測驗後流程：
  - 成績畫面：顯示本輪答對／答錯數。
  - 錯題清單畫面：本輪錯題的可滾動清單（單字、詞性、翻譯），與預習畫面共用同一個列表元件。
  - 錯題測驗：用同樣的四選一流程只考本輪錯題。干擾選項仍從整個 batch 抽（不是只從錯題抽）。錯題測驗中答錯仍會繼續累加 wrong_count。錯題測驗可循環，直到全部答對，或使用者主動退出。

## Capabilities

### New Capabilities

- `vocabulary-import`：解析 pipe 分隔的 markdown 單字輸入、驗證每一行、把解析出的卡片寫入指定 deck，並套用每 50 張自動分批的規則。
- `flashcard-deck`：Deck / Batch / Card 資料模型、以 SwiftData 做持久化，以及進入測驗前的導覽介面（deck 清單、batch 清單、批次首頁）。
- `quiz-review`：預習畫面、主測驗單輪（含答錯重排機制）、成績摘要、錯題清單，以及可循環的錯題測驗。

### Modified Capabilities

(none)

## Impact

- Affected specs: vocabulary-import (new), flashcard-deck (new), quiz-review (new)
- Affected code:
  - New: VocTest.xcodeproj/project.pbxproj
  - New: VocTest/VocTestApp.swift
  - New: VocTest/Models/Deck.swift
  - New: VocTest/Models/Batch.swift
  - New: VocTest/Models/Card.swift
  - New: VocTest/Parser/MarkdownParser.swift
  - New: VocTest/ReviewEngine/QuizSession.swift
  - New: VocTest/ReviewEngine/MistakeQuizSession.swift
  - New: VocTest/Views/DeckListView.swift
  - New: VocTest/Views/BatchListView.swift
  - New: VocTest/Views/BatchHomeView.swift
  - New: VocTest/Views/PreviewView.swift
  - New: VocTest/Views/CardListRow.swift
  - New: VocTest/Views/QuizView.swift
  - New: VocTest/Views/ResultView.swift
  - New: VocTest/Views/MistakeReviewView.swift
  - New: VocTest/Views/ImportView.swift
  - New: openspec/specs/vocabulary-import/spec.md
  - New: openspec/specs/flashcard-deck/spec.md
  - New: openspec/specs/quiz-review/spec.md
  - Modified: (none)
  - Removed: (none)
