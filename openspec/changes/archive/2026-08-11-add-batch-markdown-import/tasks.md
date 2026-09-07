## 1. Model 層批量寫入

- [x] 1.1 依「批量寫入的容量計算放在 Editor，與單筆新增同層」與「溢出切批直接重用 Importer，不另寫切批邏輯」兩項決策，在 `CardEditor` 新增剩餘容量查詢與批量寫入兩項行為。剩餘容量為 `capacity` 減去批次現有卡片數、最小為 0。另依「新批次在儲存時才建立，不存在空批次狀態」決策新增「寫入新批次」：輸入 `ParsedCard` 陣列、目標 `Deck` 與 `ModelContext`，交給 `CardImporter.appendCards` 切批並接在 deck 末端，回傳總寫入筆數與新建立的批次數，空輸入不建立任何批次。批量寫入接受解析後的 `ParsedCard` 陣列、目標 `Batch`、是否允許溢出的旗標與 `ModelContext`：先過濾未通過 `isValid` 的項目，取前「剩餘容量」筆寫入目標批次並讓 `importOrder` 接續現有最大值，仍有剩餘且允許溢出時把其餘交給 `CardImporter.appendCards` 寫入該批次所屬的 `Deck`，仍有剩餘但不允許溢出時不寫入任何一筆並回傳 nil；回傳值需含寫入目標批次的筆數、新建立的批次數與總寫入筆數。驗證：編譯通過；程式碼審閱確認切批只由 `CardImporter.appendCards` 完成，Editor 內沒有第二處切批實作。
- [x] 1.2 在 `GrammarItemEditor` 新增與 1.1 對稱的剩餘容量查詢、批量寫入與寫入新批次，操作對象為 `ParsedGrammarItem`、`GrammarBatch`、`GrammarDeck`，溢出交給 `GrammarItemImporter.appendItems`。驗證：編譯通過；程式碼審閱確認同 1.1 的條件。
- [x] 1.3 在 VocTestTests/CardEditorTests.swift 新增覆蓋「Paste Markdown Into An Existing Batch」「Over-Capacity Paste Requires An Explicit User Choice」「Abandoning An Over-Capacity Paste Writes Nothing」「Overflow Fills The Batch Then Creates New Batches」四條需求：剩餘容量在空批次、已滿批次、持有 `capacity` 減 1 筆時分別為 `capacity`、0、1；批次持有 32 筆寫入 5 筆後批次為 37 筆且新項目 `importOrder` 為 32 至 36、`wrongCount` 為 0、deck 批次數不變；批次持有 32 筆寫入 12 筆且允許溢出時目標批次滿 40、新增 1 個批次持有 4 筆且其 `importOrder` 由 0 起算；批次持有 39 筆寫入 83 筆且允許溢出時目標批次滿 40、其餘 82 筆切成 40、40、2 三個新批次；不允許溢出且超量時回傳 nil 且批次數與筆數皆不變；溢出建立的批次編號接續 deck 既有最大編號且連續不重疊；目標批次原有項目的內容欄位、`wrongCount`、`importOrder` 在批量寫入後不變。另覆蓋「Paste With A Deck Target Writes Only New Batches」：以 deck 為目標寫入 1 筆時 deck 新增 1 個含 1 筆的批次且其 `importOrder` 為 0、編號接續既有最大編號；以 deck 為目標寫入 83 筆時 deck 新增 40、40、3 三個批次；空輸入不建立任何批次且既有批次不受影響。期望值一律由 `capacity` 推導而非硬編碼。驗證：`xcodebuild test` 中這些測試全數通過。
- [x] 1.4 在 VocTestTests/GrammarItemEditorTests.swift 新增與 1.3 對稱的 `GrammarItemEditor` 批量寫入案例。驗證：`xcodebuild test` 中這些測試全數通過。

## 2. 批次貼上畫面

- [x] 2.1 在 VocTest/Views/BatchImportView.swift 建立 `BatchImportView`，以 sheet 呈現，接受兩種寫入目標之一：既有 `Batch` 或 `Deck`。畫面提供多行文字輸入、確認匯入動作，以及依「無效行與超量是兩件事，分開呈現」決策與「Invalid Lines Are Reported Separately From Overflow」需求分開的兩個回報區：無效行區列出行號與原始內容且不計入有效筆數，結果區顯示新增筆數與新建批次數。確認時以 `MarkdownParser.parse` 解析。目標為 `Batch` 時顯示剩餘容量，有效筆數未超過剩餘容量則直接呼叫 `CardEditor` 的批量寫入；目標為 `Deck` 時不顯示剩餘容量、不做超量判斷，一律呼叫「寫入新批次」。驗證：編譯通過；程式碼審閱確認寫入路徑呼叫 `CardEditor` 的批量寫入函式，畫面內未自行建立 `Card` 物件也未自行切批。
- [x] 2.2 在 VocTest/Views/GrammarBatchImportView.swift 建立與 2.1 對稱的 `GrammarBatchImportView`，以 `GrammarMarkdownParser.parse` 解析、呼叫 `GrammarItemEditor` 的批量寫入。驗證：編譯通過；程式碼審閱確認同 2.1 的條件。
- [x] 2.3 依「超量時由使用者選擇開新批次或放棄，而非系統自行決定」決策，在兩個貼上畫面加入超量確認視窗：有效筆數超過剩餘容量時顯示，說明還能放幾筆與有幾筆放不下，提供「開新批次」與「放棄此次新增」兩個選項；「開新批次」以允許溢出呼叫批量寫入，「放棄」不呼叫任何寫入函式。顯示確認視窗前不得寫入任何內容。驗證：編譯通過；程式碼審閱確認超量分支在使用者選擇前沒有任何寫入呼叫，且「放棄」分支不呼叫寫入函式；`CardEditorTests` 與 `GrammarItemEditorTests` 中「不允許溢出時回傳 nil 且不寫入」的測試通過。

- [x] 2.4 讓 `CardEditView` 與 `GrammarItemEditView` 的新增模式支援 `Deck` 目標：儲存時把該筆內容交給對應 Editor 的「寫入新批次」，在 deck 末端產生一個含 1 筆的新批次；既有的 `Batch` 目標行為完全不變。驗證：編譯通過；程式碼審閱確認 `Deck` 目標的儲存路徑呼叫「寫入新批次」而非自行建立 `Batch` 物件，且畫面在儲存前不會建立任何批次。

## 3. 預習頁選單入口

- [x] 3.1 依「「＋」改為選單入口，滿載時續往新批次而非死路」決策，在 `PreviewView` 同時實作「Creation Action Offers Manual Entry And Paste」與修訂後的「Creation Blocked At Batch Capacity」：「＋」維持不加 `.disabled`，action 先檢查 `CardEditor.canAppend`。true 時開啟恰有兩項的選單，以目前批次為目標分別開啟 `CardEditView` 新增模式與 `BatchImportView`。false 時依「「＋」改為選單入口，滿載時續往新批次而非死路」決策顯示提示視窗，提供「開新批次」與「取消」：「取消」不開啟任何畫面也不寫入；「開新批次」開啟同一個選單，但兩個選項改以所屬 `Deck` 為目標。驗證：編譯通過；程式碼審閱確認「＋」無 `.disabled`、false 分支在使用者選擇前不開啟選單、「取消」分支不呼叫任何寫入函式、「開新批次」分支傳入的目標為 `Deck` 而非批次。
- [x] 3.2 在 `GrammarPreviewView` 實作與 3.1 對稱的選單入口與滿載提示視窗，接上 `GrammarItemEditView` 新增模式與 `GrammarBatchImportView`。驗證：編譯通過；程式碼審閱確認同 3.1 的四項條件。

## 4. 整體驗收

- [x] 4.1 執行完整測試套件並做一輪跨檔案審閱，全程不開模擬器操作畫面：確認 design 的 Acceptance criteria 所列的五項程式碼審閱條件逐項成立，其中包含「專案中沒有任何地方建立不含內容的批次」，且既有的 deck 層級匯入、單筆新增與編輯、多選刪除、測驗與錯題複習流程未受影響。驗證：`xcodebuild test` 全綠（無 failure）；五項審閱條件逐項在程式碼中確認；`grep` 確認專案中除 `CardImporter` 與 `GrammarItemImporter` 外沒有其他切批實作。

## 5. 文件同步

- [x] 5.1 更新 README.md 的功能總覽，說明預習頁的「＋」提供手動輸入與貼上 Markdown 兩條路徑、貼上內容超過批次剩餘容量時由使用者選擇開新批次或放棄，以及批次已滿時可選擇把新內容放進新批次。驗證：內容審閱，確認 README.md 不再把「＋」描述為只能新增單筆。
- [x] 5.2 更新 docs/architecture.md，在 View 層與純邏輯層的關係說明中補入兩個批次貼上畫面，以及它們經 Editor 批量寫入、溢出再轉交 Importer 的資料流。驗證：內容審閱，確認架構圖或分層說明涵蓋這兩個新畫面與該資料流方向。
- [x] 5.3 更新 docs/implementation.md，記錄剩餘容量計算、部分填入的 `importOrder` 接續方式、超量時的兩個選項與各自結果，以及溢出重用 Importer 切批的理由。驗證：內容審閱，確認所述規則與 `CardEditor`、`GrammarItemEditor` 的批量寫入實際行為一致。
