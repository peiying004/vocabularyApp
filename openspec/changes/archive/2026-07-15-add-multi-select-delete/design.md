## Context

App 目前有兩條對稱的資料階層，皆以 SwiftData 建模，且 `@Relationship` 已設好 `.cascade` 刪除規則：

- 單字側：`Deck` → `Batch`（每 50 張切批）→ `Card`
- 文法側：`GrammarDeck` → `GrammarBatch`（每 20 題切批）→ `GrammarItem`

現況缺口：完全沒有刪除入口。`DeckListView` / `GrammarDeckListView` 已持有 `@Environment(\.modelContext)` 且以 `ForEach(decks)` 呈現，具備刪除條件；但 `BatchListView` / `GrammarBatchListView` 與 `PreviewView` / `GrammarPreviewView` 目前用 `List(sortedX)` 直接列舉、未注入 `modelContext`，需要改造才能刪除與多選。

批次以 `index` 欄位呈現為「批次 N」，`Batch.index` 與 `GrammarBatch.index` 目前是 `private(set)`，外部無法改寫。

## Goals / Non-Goals

**Goals:**

- 三層（分組、批次、單一項目）皆可刪除，單字側與文法側行為對稱。
- 批次層與項目層採用編輯模式多選刪除；刪除前有確認並顯示數量。
- 刪批次或把某批項目刪光後，該分組剩餘批次連續重新編號，清單不留跳號或空殼。

**Non-Goals:**

- 不做單筆左滑即刪、undo、垃圾桶。
- 不改切批規則與匯入流程。
- 不新增或改寫 SwiftData 的 cascade 規則。

## Decisions

### 統一採用 List(selection:) 加 EditButton 的編輯模式多選

批次清單與項目清單一律改為 `List(selection: $selection)`（`selection` 型別為 `Set<PersistentIdentifier>`），並在 toolbar 放 `EditButton`。正常模式下列點擊維持既有 `NavigationLink` 導覽；進入編輯模式後點擊改為勾選，底部或 toolbar 出現「刪除」動作。分組清單沿用既有 `ForEach(decks)` 一併改為 `List(selection:)` 多選刪除，維持三層一致的操作手感。

替代方案：`.onDelete` 左滑刪除——被否決，因為使用者明確偏好多選，且左滑一次只能刪一筆。

### 開放批次 index 為可寫並將重排邏輯放在 Deck / GrammarDeck

將 `Batch.index` 與 `GrammarBatch.index` 由 `private(set) var` 改為 `var`（setter 開放為 module 內可寫）。在 `Deck` 與 `GrammarDeck` 各新增一個 `reindexBatches()` 方法：取自身批次依現有 `index` 升冪排序後，由 1 起連續重新指派 `index`。任何刪批次或移除空批次的動作完成後呼叫對應 `reindexBatches()`。

替代方案：新增獨立的 reindex 服務型別——被否決，屬過度設計；重排邏輯緊貼各自 deck 的批次集合，放在 model 上最直接（刪除此方法後重排行為即失效，通過刪除測試）。

### 刪除前以確認對話框顯示數量

批次層與項目層送出刪除前，以確認對話框顯示將刪除的批次數或項目數，並提示連帶移除的卡片／題目與練習紀錄（`wrongCount`）。使用者確認才提交刪除；取消則不動任何資料並保留當前勾選。分組刪除同樣需確認，因其 cascade 影響最大。

### 題目刪光後自動移除空批次並觸發重排

項目層刪除提交後，檢查受影響批次是否 `items`／`cards` 為空；若為空則一併 `modelContext.delete(batch)`，隨後呼叫該分組的 `reindexBatches()`。批次層直接刪除批次後亦呼叫 `reindexBatches()`。

### 分組刪除沿用 cascade 且不需重排

刪除 `Deck` / `GrammarDeck` 由 SwiftData `.cascade` 連帶移除底下批次與項目，分組本身以 `createdAt` 排序、無 `index` 概念，因此分組刪除不觸發批次重排。

## Implementation Contract

**Behavior（使用者可觀察到的結果）：**

- 批次清單、項目清單、分組清單各有進入編輯模式的入口（`EditButton`）；編輯模式下可勾選多筆並刪除。
- 刪除送出前出現確認對話框，文字含將刪除的數量與「連同卡片／題目與練習紀錄一併移除」的提醒；確認才刪、取消則無變更。
- 刪除批次、或把某批項目全部刪光後：受影響空批次消失，且該分組剩餘批次顯示為「批次 1、批次 2 …」連續無跳號。
- 刪除分組後，該分組及其所有批次與項目自清單消失。

**Interface / data shape：**

- `Batch.index`、`GrammarBatch.index`：由 `private(set) var index: Int` 改為 `var index: Int`。
- `Deck.reindexBatches()`、`GrammarDeck.reindexBatches()`：新方法，將自身批次依現有 index 升冪後由 1 起連續重指派。
- 六個 View 各自新增 `@Environment(\.modelContext)`（批次／項目清單）與 `@State selection: Set<PersistentIdentifier>`、確認對話框狀態。

**Failure modes：**

- 使用者取消確認：不呼叫 `modelContext.delete`、不改 index、保留勾選。
- 空選取時的刪除動作：不可送出（刪除鈕停用或無作用）。

**Acceptance criteria：**

- 新增／更新單元測試覆蓋 `reindexBatches()`：刪中間批次後 index 連續、順序保留；空批次移除後同樣連續（對應 spec 的兩個 Example）。
- 手動驗證：在單字側與文法側分別走「刪批次」「刪光某批題目」「刪分組」三條路徑，確認清單狀態與確認對話框文案符合上述 Behavior。

**Scope boundaries：**

- 範圍內：`Batch`、`GrammarBatch` 兩個 model 的 index 可寫化與 `reindexBatches()`；`DeckListView`、`GrammarDeckListView`、`BatchListView`、`GrammarBatchListView`、`PreviewView`、`GrammarPreviewView` 六個 View 的刪除／多選／確認。
- 範圍外：匯入切批邏輯、測驗與複習流程、cascade 規則、`Card`／`GrammarItem` 的欄位。

## Risks / Trade-offs

- [編輯模式與 NavigationLink 並存可能誤觸導覽] → 使用 `List(selection:)` 搭配 `EditMode`，SwiftUI 在編輯模式下自動改為勾選、正常模式才導覽；以手動驗證確認兩模式切換正常。
- [index 由 private(set) 開放為可寫，恐被匯入流程以外的程式碼誤改] → 僅在 `reindexBatches()` 內改寫，並將該方法作為唯一重排入口；匯入流程仍走既有指派。
- [批次數量大時逐一改寫 index 造成多次寫入] → 批次數受切批規則限制（每批 20/50 筆），單一分組批次數有限，效能影響可忽略。
