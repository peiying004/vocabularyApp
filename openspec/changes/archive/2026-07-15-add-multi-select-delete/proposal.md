## Why

使用者匯入單字或文法題目後，目前完全沒有刪除機制——匯錯、重複匯入或不再需要的內容只能一直堆在清單裡。使用者明確要求能刪除匯入的題目，且希望同時支援「刪單一題」與「整批刪除」，並用編輯模式多選操作。

## What Changes

- 在**批次清單**（單字側 `BatchListView`、文法側 `GrammarBatchListView`）加入編輯模式多選刪除，一次可刪除多個批次；刪除會 cascade 移除批次底下所有卡片／題目與其練習紀錄。
- 在**題目／單字清單**（單字側 `PreviewView`、文法側 `GrammarPreviewView`）加入編輯模式多選刪除，一次可刪除多筆單一卡片／題目。
- 在**分組清單**（`DeckListView`、`GrammarDeckListView`）加入刪除分組能力；刪除分組會 cascade 移除底下所有批次與卡片／題目。
- **刪除前確認**：多選刪除送出前跳出確認對話框，顯示將刪除的數量，並提醒連帶刪除的卡片／題目與練習紀錄。
- **自動移除空批次**：在題目層刪到某批次剩 0 筆時，該空批次一併移除。
- **批次連續重新編號**：任何導致批次減少的操作（整批刪除，或空批次自動移除）之後，該分組剩餘批次依現有排序連續重新編號，清單不留跳號或空殼。這需要將 `Batch.index` 與 `GrammarBatch.index` 從 `private(set)` 開放為可寫，或提供重排方法。

## Non-Goals

- 不做單筆左滑即刪（swipe-to-delete）；一律走編輯模式多選，兩種顆粒度共用同一互動。
- 不做刪除復原（undo）或垃圾桶；刪除經確認後即永久移除。
- 不改動匯入流程本身的切批規則（單字每 50 張、文法每 20 題）。
- 不調整 cascade 刪除規則——SwiftData model 上的 `.cascade` 已設定完成，本次沿用。

## Capabilities

### New Capabilities

- `content-deletion`: 定義單字側與文法側在分組、批次、單一項目三個層級的刪除行為，包含編輯模式多選、刪除前確認、空批次自動移除，以及批次連續重新編號。

### Modified Capabilities

(none)

## Impact

- Affected specs: `content-deletion`（新增）
- Affected code:
  - Modified:
    - VocTest/Models/Batch.swift
    - VocTest/Models/GrammarBatch.swift
    - VocTest/Views/DeckListView.swift
    - VocTest/Views/GrammarDeckListView.swift
    - VocTest/Views/BatchListView.swift
    - VocTest/Views/GrammarBatchListView.swift
    - VocTest/Views/PreviewView.swift
    - VocTest/Views/GrammarPreviewView.swift
  - New:
    - (none)
  - Removed:
    - (none)
