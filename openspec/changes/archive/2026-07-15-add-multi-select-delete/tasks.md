## 1. Model 層：批次 index 可寫化與重排

- [x] 1.1 將 `Batch.index` 與 `GrammarBatch.index` 由 `private(set) var index: Int` 改為 `var index: Int`，使其 setter 於 module 內可寫。驗證：專案編譯通過，且 `reindexBatches()` 能對 index 重新指派。（設計決策：開放批次 index 為可寫並將重排邏輯放在 Deck / GrammarDeck）
- [x] 1.2 在 `Deck` 與 `GrammarDeck` 各新增 `reindexBatches()`：取自身批次依現有 index 升冪排序後，由 1 起連續重新指派 index，順序保留，實現需求 Contiguous Batch Renumbering。驗證：新增單元測試，涵蓋 design/spec 的兩個 Example——刪中間批次（1,2,3→刪2）後存活批次為 index=1(原1)、index=2(原3)；空批次移除後結果相同、無跳號或重複。（設計決策：開放批次 index 為可寫並將重排邏輯放在 Deck / GrammarDeck）

## 2. 批次層多選刪除

- [x] 2.1 `BatchListView` 改為 `List(selection:)` + `EditButton`，注入 `@Environment(\.modelContext)`，可在編輯模式勾選多個批次；送出前跳確認對話框顯示批次數並提示連帶移除卡片與練習紀錄，確認後刪除選取批次並呼叫 `deck.reindexBatches()`，取消則不變更、保留勾選。此任務實現需求 Multi-Select Batch Deletion 與 Deletion Confirmation。驗證：手動在單字側刪多個批次，確認剩餘批次連號無跳號、取消不刪、正常模式仍可導覽。（設計決策：統一採用 List(selection:) 加 EditButton 的編輯模式多選；刪除前以確認對話框顯示數量）
- [x] 2.2 `GrammarBatchListView` 套用與 2.1 對稱的批次多選刪除、確認與 `deck.reindexBatches()` 呼叫，同樣實現需求 Multi-Select Batch Deletion 與 Deletion Confirmation。驗證：手動在文法側刪多個批次，確認行為與單字側一致。（設計決策：統一採用 List(selection:) 加 EditButton 的編輯模式多選）

## 3. 項目層多選刪除與空批次移除

- [x] 3.1 `PreviewView` 改為 `List(selection:)` + `EditButton`，注入 `@Environment(\.modelContext)`，可勾選多筆 `Card` 刪除；送出前確認顯示題目數，確認後刪除選取項目，若所屬 `Batch` 變空則一併刪除該批次並呼叫 `deck.reindexBatches()`。此任務實現需求 Multi-Select Item Deletion、Empty Batch Auto-Removal 與 Deletion Confirmation。驗證：手動刪部分卡片保留其餘；刪光某批全部卡片後該批次消失且剩餘批次連號。（設計決策：題目刪光後自動移除空批次並觸發重排）
- [x] 3.2 `GrammarPreviewView` 套用與 3.1 對稱的 `GrammarItem` 多選刪除、空批次移除與重排，同樣實現需求 Multi-Select Item Deletion 與 Empty Batch Auto-Removal。驗證：手動在文法側重現 3.1 兩種情境，行為一致。（設計決策：題目刪光後自動移除空批次並觸發重排）

## 4. 分組層刪除

- [x] 4.1 `DeckListView` 改為支援刪除 `Deck`（`List(selection:)` + `EditButton`），送出前確認並提示 cascade 連帶移除底下批次與卡片，確認後刪除。此任務實現需求 Deck Deletion 與 Deletion Confirmation。驗證：手動刪除含批次的分組，確認分組與其所有批次、卡片消失。（設計決策：分組刪除沿用 cascade 且不需重排）
- [x] 4.2 `GrammarDeckListView` 套用與 4.1 對稱的 `GrammarDeck` 刪除與確認，同樣實現需求 Deck Deletion。驗證：手動刪除含批次的文法分組，確認 cascade 生效。（設計決策：分組刪除沿用 cascade 且不需重排）

## 5. 整體驗證

- [x] 5.1 於單字側與文法側分別走「刪批次」「刪光某批題目」「刪分組」三條路徑做端到端手動驗證，並執行既有測試套件（含 1.2 新增測試）確認全數通過。驗證：所有測試綠燈，三條路徑清單狀態與確認對話框文案符合 design 的 Behavior。
