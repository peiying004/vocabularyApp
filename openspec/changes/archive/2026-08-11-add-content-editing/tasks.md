## 1. Model 層編輯器

- [x] 1.1 依「驗證與批次變更邏輯放在 Model 層的 CardEditor 與 GrammarItemEditor」決策，在 VocTest/Models/CardEditor.swift 建立 `CardEditor`，提供 `capacity`（等於 `CardImporter.chunkSize`）、欄位驗證、可否新增判斷、新增卡片、更新既有卡片內容、刪除卡片六項行為。驗證規則依「Edit Validation Matches Import Rules」：`word` 與 `translation` 去除前後空白後非空，`partOfSpeech` 為空時存為 nil。新增行為依「Single Item Creation Within A Batch」指派 `importOrder` 為現有最大值加 1、`wrongCount` 為 0。刪除行為依「Single Item Deletion From The Editing Screen」在批次清空時移除批次並呼叫 `Deck.reindexBatches()`，回傳批次是否被移除。驗證：型別可編譯且 `Card.wrongCount` 維持 `private(set)` 未被放寬。
- [x] 1.2 在 VocTest/Models/GrammarItemEditor.swift 建立與 `CardEditor` 對稱的 `GrammarItemEditor`，`capacity` 等於 `GrammarItemImporter.chunkSize`。驗證規則為 `question` 與 `correct` 去除前後空白後非空，且依「Fixed Distractor Count」要求 `distractors` 恰有 3 個元素、每個去除前後空白後皆非空，`explanation` 為空時存為 nil。驗證：型別可編譯且 `GrammarItem.wrongCount` 維持 `private(set)` 未被放寬。
- [x] 1.3 在 VocTestTests/CardEditorTests.swift 以記憶體內 `ModelContainer` 覆蓋 `CardEditor` 的行為：驗證通過與失敗的欄位組合（含只含空白的字串）、新增時 `importOrder` 為最大值加 1 且 `wrongCount` 為 0、依「Batch Capacity Invariant」對已滿的批次新增會被拒絕且卡片數不變、刪除批次中唯一一張卡會移除批次且剩餘批次編號由 1 起連續、刪除多張中的一張時其餘卡片 `importOrder` 不變，以及依「Practice Records And Ordering Preserved On Edit」修改內容後 `wrongCount` 與 `importOrder` 保持原值。驗證：`xcodebuild test` 中這些測試全數通過。
- [x] 1.4 在 VocTestTests/GrammarItemEditorTests.swift 覆蓋與 1.3 對稱的 `GrammarItemEditor` 案例，另加干擾選項不足 3 個、超過 3 個、含空字串時驗證失敗的案例。驗證：`xcodebuild test` 中這些測試全數通過。

## 2. 編輯畫面

- [x] 2.1 依「兩側編輯畫面各自獨立，不共用抽象」決策，在 VocTest/Views/CardEditView.swift 建立 `CardEditView`，同時支援編輯既有卡片與新增兩種模式，以本地暫存狀態承接輸入、按下儲存時才寫回模型，取消時不留下任何變更。畫面提供 `word`、`partOfSpeech`、`translation` 三個欄位。依「編輯內容不影響練習紀錄與排序位置」，儲存只寫入內容欄位。驗證：編譯通過；程式碼審閱確認「儲存」的 `.disabled` 綁在 `CardEditor.isValid`，且儲存路徑呼叫 `CardEditor.update` 或 `CardEditor.appendCard` 而非直接寫入模型欄位；`CardEditorTests` 中對應的驗證與新增測試通過。
- [x] 2.2 在 VocTest/Views/GrammarItemEditView.swift 建立與 2.1 對稱的 `GrammarItemEditView`，提供 `question`、`correct`、`explanation` 與依「Fixed Distractor Count」固定呈現的 3 個干擾選項欄位，畫面上不提供增減干擾選項的控制項。驗證：編譯通過；程式碼審閱確認干擾選項欄位數量取自 `GrammarItemEditor.distractorCount` 且無新增或移除欄位的控制項，「儲存」的 `.disabled` 綁在 `GrammarItemEditor.isValid`；`GrammarItemEditorTests` 中對應的驗證測試通過。
- [x] 2.3 依「刪除單筆沿用既有的刪除鏈」決策，在兩個編輯畫面的既有內容模式下加入「刪除」，經 `confirmationDialog` 確認後才呼叫對應編輯器的刪除行為；取消確認時不刪除且畫面保持開啟。刪除後關閉編輯畫面，若批次因此被移除則一併關閉預習頁。驗證：編譯通過；程式碼審閱確認刪除路徑經 `confirmationDialog`、呼叫 Editor 的 delete、並以其回傳值決定是否關閉預習頁；`CardEditorTests` 與 `GrammarItemEditorTests` 中刪除單筆與刪除批次最後一筆（含批次重新編號）的測試通過。

## 3. 預習頁整合

- [x] 3.1 依「編輯入口沿用預習頁，不另建內容管理畫面」與「編輯入口使用 NavigationLink，不自行仲裁點選手勢」兩項決策，在 `PreviewView` 實作「Single Item Editing」：編輯入口只從所屬批次的預習頁進入，不另建管理畫面；每一列以 `NavigationLink` 推入 `CardEditView` 的編輯模式並預先填入該卡現值，編輯模式下的多選語意由 `List(selection:)` 內建接管。工具列加入「＋」以 sheet 開啟新增模式的 `CardEditView`，新卡片寫入當前批次。驗證：編譯通過；程式碼審閱確認列為 `NavigationLink`、檔案中不存在任何讀取 `editMode` 的自訂點選處理，且未新增任何跨批次的內容列表畫面。
- [x] 3.2 在 `GrammarPreviewView` 實作與 3.1 對稱的編輯與新增入口，接上 `GrammarItemEditView`。驗證：編譯通過；程式碼審閱確認同 3.1 的兩項條件。
- [x] 3.3 依「滿載時以提示視窗阻擋，而非停用新增按鈕」決策，在兩個預習頁實作「Creation Blocked At Batch Capacity」：「＋」不加 `.disabled`，其 action 先檢查對應 Editor 的 `canAppend`，為 false 時顯示提示視窗（說明批次已滿並指引改用匯入功能）且不開啟編輯畫面，為 true 時才開啟。移除原本列表下方的常駐滿載說明文字。驗證：編譯通過；程式碼審閱確認兩個預習頁的「＋」無 `.disabled` 修飾、action 內有 `canAppend` 分支且 false 分支不開啟編輯畫面，且檔案中不再有常駐的容量說明文字；`CardEditorTests` 與 `GrammarItemEditorTests` 中「對已滿批次新增被拒絕且不建立新批次」的測試通過。

## 4. 錯誤次數重置

- [x] 4.1 依「錯誤次數重置限定批次層級，按鈕放在批次首頁」決策，在 VocTest/Models/Card.swift 與 VocTest/Models/GrammarItem.swift 各新增一個無參數、無回傳值的 `resetWrongCount()` 實例方法，把自身 `wrongCount` 設為 0。依「Batch-Level Wrong Count Reset」保持 `wrongCount` 的 `private(set)` 宣告不變，不新增可寫屬性。驗證：型別可編譯，且 `wrongCount` 在兩個模型中仍為 `private(set)`。
- [x] 4.2 在 `BatchHomeView` 加入「重算錯誤次數」，經 `confirmationDialog` 確認後對該批次每一張卡呼叫 `resetWrongCount()`；該批次 `wrongCount` 加總為 0 時按鈕停用；取消確認時不改動任何值。顯示的「累計錯 N 次」與按鈕停用狀態皆由該加總推導，不另存狀態。驗證：編譯通過；程式碼審閱確認重置路徑經 `confirmationDialog`、對批次內每個項目呼叫 `resetWrongCount()`、按鈕 `.disabled` 綁在加總為 0 的條件，且未寫入任何內容欄位或 `importOrder`；`ModelTests` 中重置歸零、重置後重新累計、重置不動內容與順序的測試通過。
- [x] 4.3 在 `GrammarBatchHomeView` 加入與 4.2 對稱的「重算錯誤次數」，操作對象為該批次的 `GrammarItem`。驗證：編譯通過；程式碼審閱確認同 4.2 的四項條件；`GrammarModelTests` 中對稱的重置測試通過。
- [x] 4.4 在 VocTestTests/VocTestTests.swift 的 `ModelTests` 新增測試覆蓋 `Card.resetWrongCount()`：重置後 `wrongCount` 為 0；重置後再呼叫 `recordWrong()` 能由 0 重新累計；依「Reset Is Explicit And Never Automatic」確認重置不改動 `word`、`partOfSpeech`、`translation`、`importOrder`。在 VocTestTests/GrammarModelTests.swift 新增 `GrammarItem.resetWrongCount()` 的對稱測試。既有的 `testWrongCountIsMonotonicViaRecordWrong` 保留不動。驗證：`xcodebuild test` 中新增與既有測試全數通過。

## 5. 批次容量統一為 40

- [x] 5.1 依「批次容量統一為 40 且維持嚴格上限」決策，把 `CardImporter.chunkSize` 由 50、`GrammarItemImporter.chunkSize` 由 20 都改為 40，並更新這兩個檔案中互相指涉對方數值的註解。依「Automatic 50-Card Batching On Persist」的修訂內容，匯入 130 筆會切成 40、40、40、10 四批。驗證：編譯通過；`grep` 確認專案原始碼中批次容量只在這兩個常數宣告處出現字面值。
- [x] 5.2 更新受容量變更影響的既有測試期望值：`CardEditorTests` 與 `GrammarItemEditorTests` 中以 50／20 為界的容量測試改以 40 為界，`CardImporterTests` 與 `AcceptanceTests` 中的切批期望值改為 40 基準。期望值一律由 `chunkSize` 推導而非硬編碼字面值，使日後再調整容量時不需重寫測試。驗證：`xcodebuild test` 全數通過；`grep` 確認測試檔中不再有硬編碼的批次容量 50 或 20。
- [x] 5.3 更新使用者看得到的容量文案與說明註解：`BatchListView` 與 `GrammarBatchListView` 空狀態的「每 N 張／題切成一批」，以及 `Batch.swift`、`GrammarBatch.swift`、`CardEditor.swift`、`GrammarItemEditor.swift` 的說明註解。驗證：編譯通過；程式碼審閱確認這些文字所述數量與 `chunkSize` 一致。

## 6. 整體驗收

- [x] 6.1 依「驗收不含模擬器互動操作」決策執行本 change 的最終驗收，全程不開模擬器操作畫面：執行完整測試套件，並做一輪跨檔案審閱，確認既有的匯入、多選刪除、測驗與錯題複習流程未因容量變更或編輯功能而失效，且 design 的 Acceptance criteria 所列的六項 UI 綁定條件逐項成立。驗證：`xcodebuild test` 全綠（無 failure）；六項綁定條件逐項在程式碼中確認；確認沒有任何任務的驗收目標仍要求手動操作模擬器。

## 7. 文件同步

- [x] 7.1 依「同步更新專案說明文件」決策，更新 README.md 的功能說明，使其反映匯入後的內容可就地編輯、新增與刪除、累計錯誤次數可依批次重算，並說明批次容量對手動新增同樣是硬上限。驗證：內容審閱，確認 README.md 不再有「匯入後內容固定」語意的描述。
- [x] 7.2 更新 docs/architecture.md，補入 `CardEditor` 與 `GrammarItemEditor` 在 Model 層的位置與職責、`CardEditView` 與 `GrammarItemEditView` 在 View 層與兩個預習頁的關係，以及 `resetWrongCount()` 在 `Card` 與 `GrammarItem` 上與 `recordWrong()` 對稱的定位。驗證：內容審閱，確認架構圖或分層說明涵蓋這四個新型別與新方法。
- [x] 7.3 更新 docs/implementation.md，記錄編輯與新增的驗證規則、`importOrder` 指派方式、批次容量上限的處理、刪除時的空批次移除與重新編號行為，以及批次層級錯誤次數重置的觸發條件與停用條件。驗證：內容審閱，確認所述規則與 `CardEditor`、`GrammarItemEditor`、`resetWrongCount()` 的實際行為一致。
- [x] 7.4 把四份文件中的批次容量數字統一更新為 40：README.md 的功能總覽、docs/architecture.md 的資料模型與專案結構、docs/implementation.md 的切批與容量段落、docs/getting-started.md 的匯入說明。同時更新 docs/implementation.md 中「滿載停用按鈕」的敘述為「滿載跳提示視窗」，以及編輯入口由 sheet 改為 `NavigationLink` 的描述。驗證：內容審閱；`grep` 確認四份文件中不再出現以每批 50 或每批 20 描述批次容量的句子。
