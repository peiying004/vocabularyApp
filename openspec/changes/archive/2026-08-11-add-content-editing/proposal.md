## Why

目前匯入單字或文法題之後，內容是唯讀的。`PreviewView` 與 `GrammarPreviewView` 只提供「多選刪除」，沒有任何修改路徑。使用者發現一個錯字、一個翻譯不精準、或一題的干擾選項寫錯，唯一的辦法是把整個批次刪掉、回到匯入頁重貼一次 Markdown —— 連帶把整批的答錯次數（`wrongCount`）練習紀錄全部丟掉。

同樣地，想補進一兩個新單字也必須走匯入流程，而匯入一定會建立新批次，無法把內容加進既有批次。

第三個缺口在練習紀錄本身。`wrongCount` 只增不減，批次首頁與批次列表顯示的「累計錯 N 次」會無限累積。使用者把一個批次練熟之後想重新計算成效，目前同樣只能刪掉整批重匯。

此外，兩側的批次容量目前不一致（單字 50、文法 20），使用者難以形成單一的「一批多少題」心智模型。

## What Changes

- 在單字預習頁與文法預習頁，非編輯模式下選取一列會進入該筆內容的編輯畫面。
- 新增單字編輯畫面：可修改 `word`、`partOfSpeech`、`translation`。
- 新增文法題編輯畫面：可修改 `question`、`correct`、3 個 `distractors`、`explanation`。
- 編輯畫面提供「刪除這一筆」，沿用既有的空批次自動移除與批次重新編號行為。
- 兩個預習頁的工具列新增「＋」，可在**當前批次**末端新增一筆內容，`importOrder` 接續現有最大值，`wrongCount` 從 0 起算。
- **批次容量統一為 40**（原本單字 50、文法 20）。匯入切批數量與手動新增上限共用同一個常數。
- 批次已滿時「＋」仍可按，按下後顯示提示視窗說明批次已滿並指引使用者改用匯入功能，且不新增任何內容。
- 儲存時套用與匯入解析器相同的必填驗證；欄位不合法時「儲存」停用。
- 編輯內容不會重置 `wrongCount`，也不會改變 `importOrder`。
- 批次首頁（`BatchHomeView`、`GrammarBatchHomeView`）新增「重算錯誤次數」，經確認後把該批次所有項目的 `wrongCount` 歸零；該批次累計為 0 時按鈕停用。
- `Card` 與 `GrammarItem` 新增 `resetWrongCount()` 具名方法，`wrongCount` 仍維持 `private(set)`。

## Non-Goals

- 不做跨批次的內容管理畫面。
- 不支援把一筆內容搬到別的批次，也不支援調整批次內順序。
- 不支援增減文法題的干擾選項數量。
- 不支援手動建立空批次。
- 不重新切分既有批次。容量改為 40 之前建立的批次維持原樣。
- 不提供批次層級的 Markdown 貼上匯入。「＋」只開手動輸入表單；批量新增仍走 deck 層級的匯入頁。此能力另以獨立 change 處理。
- 不建立 XCUITest target。本 change 的驗收不含任何模擬器互動操作。

## Capabilities

### New Capabilities

- `content-editing`: 匯入後的內容與練習紀錄維護 —— 單筆內容編輯、單筆新增、單筆刪除、批次容量已滿時的新增阻擋，以及批次層級的錯誤次數重置。

### Modified Capabilities

- `vocabulary-import`: 切批數量由單字 50 / 文法 20 統一為 40，並新增一條批次容量不變量的需求，把這個數字從匯入時的切批數量提升為所有寫入批次的操作都必須遵守的上限。

## Impact

- Affected specs:
  - 新增 `content-editing`
  - 修改 `vocabulary-import`（切批數量改為 40、新增批次容量不變量需求）
- Affected code:
  - New:
    - VocTest/Models/CardEditor.swift
    - VocTest/Models/GrammarItemEditor.swift
    - VocTest/Views/CardEditView.swift
    - VocTest/Views/GrammarItemEditView.swift
    - VocTestTests/CardEditorTests.swift
    - VocTestTests/GrammarItemEditorTests.swift
  - Modified:
    - VocTest/Models/Card.swift
    - VocTest/Models/GrammarItem.swift
    - VocTest/Models/CardImporter.swift
    - VocTest/Models/GrammarItemImporter.swift
    - VocTest/Models/Batch.swift
    - VocTest/Models/GrammarBatch.swift
    - VocTest/Views/PreviewView.swift
    - VocTest/Views/GrammarPreviewView.swift
    - VocTest/Views/BatchHomeView.swift
    - VocTest/Views/GrammarBatchHomeView.swift
    - VocTest/Views/BatchListView.swift
    - VocTest/Views/GrammarBatchListView.swift
    - VocTestTests/VocTestTests.swift
    - VocTestTests/GrammarModelTests.swift
    - VocTestTests/CardImporterTests.swift
    - VocTestTests/AcceptanceTests.swift
    - README.md
    - docs/architecture.md
    - docs/implementation.md
    - docs/getting-started.md
  - Removed: （無）
- 不影響資料模型結構：`Card`、`GrammarItem`、`Batch`、`GrammarBatch` 皆不需新增欄位。`Card` 與 `GrammarItem` 只新增 `resetWrongCount()` 方法，`wrongCount` 的 `private(set)` 保護維持不變。
- 不影響測驗與錯題複習行為：`wrongCount` 僅供批次首頁與批次列表顯示，錯題複習的題目來源是當輪測驗答錯的卡片，不讀取 `wrongCount`。
- 不需資料遷移：目前沒有超過 40 筆的既有批次。
- 不需修改 VocTest.xcodeproj/project.pbxproj：專案使用檔案系統同步群組，新增的 Swift 檔會自動納入 target。
