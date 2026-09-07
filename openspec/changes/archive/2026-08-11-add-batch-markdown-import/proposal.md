## Why

`add-content-editing` 讓使用者能在既有批次末端手動補一筆內容，但一次只能一筆。要一次補十幾個單字，目前只有兩條路：在「＋」的表單裡逐筆輸入十幾次，或改用 deck 層級的匯入頁——後者一定在 deck 末端另建新批次，無法把內容補進正在複習的那一批。

結果是「我這批還有空位，想把這幾個字加進來」這個很自然的需求沒有對應的操作。

## What Changes

- 預習頁的「＋」由「直接開啟手動表單」改為跳出選單，提供兩條路徑：`手動輸入一筆`（沿用既有表單）與 `貼上 Markdown`。
- 新增批次層級的 Markdown 貼上畫面：解析後把內容寫入**目前這個批次**，`importOrder` 接續現有最大值，`wrongCount` 由 0 起算。
- 無效行維持既有規則：跳過並列出行號，與「超量」分開呈現。
- 當有效筆數超過該批次剩餘格數時，跳出確認視窗讓使用者選擇：
  - **開新批次**：先把目前批次填滿至上限，其餘依 40 一批接在 deck 末端切成新批次。
  - **放棄此次新增**：一筆都不寫入，批次維持原狀。
- 當有效筆數未超過剩餘格數時，直接全部寫入該批次，不跳確認視窗。
- 批次已滿時按「＋」不再是死路：顯示提示視窗說明批次已滿，並提供「開新批次」與「取消」。選「開新批次」後開啟同一個選單，兩條路徑的內容都寫入 deck 末端新建立的批次；選「取消」則什麼都不做。
- 新批次一律在儲存時才建立，內容與批次一起產生，不會出現空批次。手動輸入一筆會產生一個含 1 筆的新批次。

## Non-Goals

- 不改變 deck 層級匯入頁（`ImportView` / `GrammarImportView`）的既有行為。
- 不支援從檔案選取匯入到單一批次。批次層級只提供貼上文字。
- 不改變解析器的欄位規則或容錯行為。
- 不改變批次容量 40，也不重新切分既有批次。
- 不支援讓使用者指定溢出內容要進入哪一個既有批次；溢出一律建立新批次接在 deck 末端。
- 不提供「建立空批次」的動作。批次只在有內容寫入時才被建立。
- 不提供匯入的復原（undo）。
- 驗收不含任何模擬器互動操作，也不建立 XCUITest target。

## Capabilities

### New Capabilities

- `batch-markdown-import`: 在單一既有批次內貼上 Markdown 批量新增內容，含剩餘容量計算與超量時的使用者選擇（開新批次或放棄）。

### Modified Capabilities

- `content-editing`: 「＋」的行為由直接開啟編輯畫面改為開啟選單；滿載時不再完全阻擋，改為提供「開新批次」讓使用者把內容放進新批次。

## Impact

- Affected specs:
  - 新增 `batch-markdown-import`
  - 修改 `content-editing`（「＋」改為選單入口，滿載時改為可續往新批次）
- Affected code:
  - New:
    - VocTest/Views/BatchImportView.swift
    - VocTest/Views/GrammarBatchImportView.swift
  - Modified:
    - VocTest/Models/CardEditor.swift
    - VocTest/Models/GrammarItemEditor.swift
    - VocTest/Views/PreviewView.swift
    - VocTest/Views/GrammarPreviewView.swift
    - VocTestTests/CardEditorTests.swift
    - VocTestTests/GrammarItemEditorTests.swift
    - README.md
    - docs/architecture.md
    - docs/implementation.md
  - Removed: （無）
- 不影響資料模型結構：`Card`、`GrammarItem`、`Batch`、`GrammarBatch` 皆不需新增欄位。
- 溢出建立新批次沿用既有的 `CardImporter.appendCards` 與 `GrammarItemImporter.appendItems`，不另寫切批邏輯。
- 不需修改 VocTest.xcodeproj/project.pbxproj：專案使用檔案系統同步群組，新增的 Swift 檔會自動納入 target。
- **前置相依**：本 change 對 `content-editing` 提出 MODIFIED 需求，而該 capability 的主 spec 要等 `add-content-editing` 歸檔後才會存在。請先歸檔 `add-content-editing`，再開始實作本 change，否則歸檔時無法正確套用修訂。
