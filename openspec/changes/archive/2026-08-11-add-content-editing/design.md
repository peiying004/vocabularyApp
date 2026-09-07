## Context

VocTest 的資料階層是 `Deck → Batch → Card` 與 `GrammarDeck → GrammarBatch → GrammarItem`。內容只有一條進入系統的路徑：匯入頁把 Markdown 交給 `MarkdownParser` / `GrammarMarkdownParser` 解析，再由 `CardImporter` / `GrammarItemImporter` 依 `chunkSize`（單字 50、文法 20）切批寫入。

進入系統之後，內容就是唯讀的。兩個預習頁 `PreviewView` 與 `GrammarPreviewView` 目前的互動只有 `EditButton` 帶出的多選刪除，列本身（`CardListRow`、`GrammarItemRow`）是純顯示元件，沒有點擊行為。`content-deletion` 能力已經建立了「編輯模式 → 多選 → 確認對話框 → 刪除 → 空批次自動移除 → `reindexBatches()` 重新編號」這條完整的刪除鏈。

現有限制：

- 修改任何一個欄位都必須刪整批重匯，連帶丟失整批的 `wrongCount` 練習紀錄。
- 想補一兩筆內容只能走匯入，而匯入一定在 deck 末端建立新批次，無法寫進既有批次。
- `wrongCount` 只增不減。批次首頁與批次列表顯示的「累計錯 N 次」會無限累積，練熟之後無法重新計算成效。

`wrongCount` 的實際用途值得先釐清：它只出現在四個顯示點（`BatchListView`、`BatchHomeView`、`GrammarBatchListView`、`GrammarBatchHomeView`），全是批次層級的加總。它不參與任何邏輯判斷 —— 錯題複習的題目來源是當輪測驗答錯的卡片，由結果摘要傳入 `MistakeReviewView`，不讀取 `wrongCount`。因此它是純統計數字，重置它不會改變任何功能行為。

約束：

- `Card.wrongCount` 與 `GrammarItem.wrongCount` 是 `private(set)`，只能經 `recordWrong()` 遞增。這個保護必須維持。
- `Batch.cards` 與 `GrammarBatch.items` 是 `private(set)`，只能透過 SwiftData 反向關聯（設定 `card.batch = batch`）加入成員。
- `GrammarQuizSession` 以「正解 + 3 個干擾選項」組成固定四個選項，干擾選項數量不可變動。
- 專案使用檔案系統同步群組（`PBXFileSystemSynchronizedRootGroup`），新增 Swift 檔會自動納入 target。
- 現有測試只覆蓋 Models / Parser / ReviewEngine 三層，不測 SwiftUI View。

## Goals / Non-Goals

**Goals:**

- 讓使用者能就地修改任何一筆已匯入的單字或文法題，不必刪整批重匯。
- 修改內容時保留該筆的 `wrongCount` 練習紀錄與 `importOrder` 排序位置。
- 讓使用者能在既有批次內新增與刪除單筆內容。
- 讓編輯後的資料不可能違反匯入解析器的必填規則。
- 讓新增與刪除的批次容量、編號行為可被單元測試覆蓋。
- 讓使用者能主動把一個批次的累計錯誤次數歸零，重新計算該批次的練習成效。

**Non-Goals:**

- 不做跨批次的內容管理畫面。編輯入口一律從所屬批次的預習頁進入。
- 不支援把一筆內容搬到別的批次，也不支援調整批次內的順序（`importOrder` 一經指定即固定）。
- 不支援增減文法題的干擾選項數量，固定為 3 個。
- 不支援手動建立空批次。批次仍只由匯入建立。
- 不提供編輯的復原（undo）或版本歷史。
- 不重新切分容量改為 40 之前建立的既有批次。
- 不提供批次層級的 Markdown 貼上匯入。「＋」只開手動輸入表單；此能力另以獨立 change 處理。
- 不建立 XCUITest target，驗收不含任何模擬器互動操作。
- 編輯、新增、刪除內容都不會自動重置 `wrongCount`。重置只在使用者於批次首頁明確觸發時發生。
- 錯誤次數重置不做分組（deck）層級、單筆層級或全 App 層級，只做批次層級。
- 不新增可任意寫入 `wrongCount` 的介面。重置一律經由具名方法。

## Decisions

### 編輯入口沿用預習頁，不另建內容管理畫面

`PreviewView` 與 `GrammarPreviewView` 已經是逐筆列出批次內容的清單，依 `importOrder` 排序。使用者想改的那一筆就在眼前，這是最短的操作路徑。

具體行為：非編輯模式下點選一列，以 sheet 開啟該筆的編輯畫面；編輯模式（`EditButton` 啟用時）維持現有的多選刪除語意不變。工具列新增一個「＋」按鈕開啟新增用的編輯畫面。

替代方案：另做一個獨立的內容管理畫面，可跨批次瀏覽與搜尋。否決原因是要多一層導覽層級與一套新的查詢邏輯，而使用者的實際情境是「預習時發現這一題有錯」，當下就在預習頁。

### 驗證與批次變更邏輯放在 Model 層的 CardEditor 與 GrammarItemEditor

新增兩個 Model 層型別 `CardEditor` 與 `GrammarItemEditor`，與既有的 `CardImporter` / `GrammarItemImporter` 對稱，同樣是不涉及 UI 的純資料層 enum。它們承載三件有實質行為的職責：

1. 欄位驗證規則（與解析器的必填規則一致）。
2. 新增時的容量檢查與 `importOrder` 指派。
3. 刪除時的空批次移除與 `reindexBatches()` 呼叫。

替代方案：把這些邏輯寫在 View 裡。否決原因是現有測試不覆蓋 SwiftUI View，寫在 View 裡等於這三項規則完全沒有測試；而容量上限與編號連續性正是最需要迴歸保護的部分。

這一層不是轉發用的空殼：移除它之後，驗證規則、容量守則與空批次清理都會失去歸屬與測試覆蓋。

### 兩側編輯畫面各自獨立，不共用抽象

`Card`（`word` / `partOfSpeech` / `translation`）與 `GrammarItem`（`question` / `correct` / `distractors` / `explanation`）欄位完全不同、驗證規則不同、批次容量也不同（50 對 20）。建立 `CardEditView` 與 `GrammarItemEditView` 兩個獨立的 SwiftUI View，各自以 `@Bindable` 綁定自己的模型。

這與專案既有的成對模式一致：`MarkdownParser` / `GrammarMarkdownParser`、`CardImporter` / `GrammarItemImporter`、`QuizSession` / `GrammarQuizSession` 都是兩側對稱但各自獨立。

替代方案：抽出泛型的可編輯內容協定讓兩個畫面共用。否決原因是該協定只會轉發欄位讀寫，本身不含任何行為，且會讓兩側不同的驗證規則互相牽制。

### 批次容量統一為 40 且維持嚴格上限

兩側容量統一為 40（原本單字 50、文法 20），讓使用者只需記住一個數字。這個值仍由匯入的 `chunkSize` 單一定義，兩個 Editor 的 `capacity` 取自它，因此「匯入切成幾批」與「手動最多能加到幾筆」不可能不一致。

若只改手動新增上限而不改切批數量，匯入會直接產生超過上限的批次，自相矛盾；因此兩者必須一起改。

不重新切分既有批次：目前沒有超過 40 筆的批次，不需要資料遷移。即使將來有，自動重切也會打散批次歸屬與 `importOrder` 並觸發重新編號，讓內容在批次之間跳動。

`QuizSession` 與 `GrammarQuizSession` 的 `sampleSize` 預設值原本分別寫死 50 與 20，也就是當時各自的批次容量，用意是讓一輪測驗涵蓋整批（所有正式呼叫端都使用預設值）。容量改為 40 之後，文法側若維持 20 會讓 40 題的批次每輪只測到一半，是無聲的行為退化。因此兩個預設值改為取自對應的 `chunkSize`，維持「一輪涵蓋整批」的原意，並讓容量成為單一調整點。這動到 ReviewEngine，但改的是預設值的來源而非測驗流程本身 —— 不改反而會改變測驗行為。

替代方案一，允許超出上限：否決，因為批次是「一次唸多少」的分量單位，允許無限成長會讓這個單位失去意義。

替代方案二，自動溢位到下一批：否決，因為連鎖重排會改變既有批次的內容與 `importOrder`，使用者在批次 1 操作卻看到批次 2、3 的內容變動，是無法預期的副作用。

替代方案三，滿載時自動在 deck 末端建立新批次：否決，因為「在批次 1 按新增，東西出現在批次 3」同樣違反操作與結果的對應關係；且手動建立的批次與 `content-deletion` 的「空批次不得留存」規則會產生狀態衝突。

### 滿載時以提示視窗阻擋，而非停用新增按鈕

「＋」永遠可按。批次已達上限時按下它會顯示提示視窗，說明批次已滿、指引使用者改用匯入功能，並且不新增任何內容。

這取代了原本「按鈕停用 + 列表下方灰字說明」的做法。兩者互斥：停用的按鈕按不下去，就不會有「按下之後才知道為什麼」這個動作。改用提示視窗之後，列表下方的常駐灰字變成噪音，一併移除。

替代方案，維持停用並保留灰字：否決。停用狀態要能被理解，說明文字就必須一直佔著版面；而使用者真正需要知道原因的時機只有「他想新增」的那一刻。提示視窗把說明送到需要的時間點，而不是一直放在那裡。

### 編輯入口使用 NavigationLink，不自行仲裁點選手勢

預習頁的每一列以 `NavigationLink` 推入編輯頁。在 `List(selection:)` 進入編輯模式時，SwiftUI 內建會讓 selection 接管、`NavigationLink` 不再導航，因此「編輯模式多選、非編輯模式進編輯頁」這個切換不需要程式碼自行判斷 `editMode`。

替代方案，在列上掛 `.onTapGesture` 並自行檢查 `editMode`：否決。這個做法要和 List 的 selection 手勢競爭，失效時不會有編譯錯誤、也不會有任何測試抓得到，只能靠手動操作模擬器才會發現。本 change 的驗收不含模擬器互動（見下），所以必須選一個不會無聲失效的機制。

代價：編輯既有內容從 sheet 變成推入的頁面。「＋」新增仍以 sheet 呈現 —— 它是工具列按鈕，不在列表列上，沒有手勢競爭問題。

### 編輯內容不影響練習紀錄與排序位置

編輯只寫入內容欄位。`importOrder` 在編輯時不重新指派，`wrongCount` 不受編輯影響。改一張卡的翻譯之後，它的答錯次數與在批次中的位置都不變。

替代方案：改題目視同新題目，自動重置 `wrongCount`。否決原因是使用者修正錯字的意圖是「這還是同一題，只是寫錯了」，清掉練習紀錄違反預期。重置練習紀錄是獨立的、由使用者明確觸發的動作，見下一則決策。

### 錯誤次數重置限定批次層級，按鈕放在批次首頁

`wrongCount` 只增不減，「累計錯 N 次」會無限累積。提供一個明確的重置動作，讓使用者把練熟的批次歸零重新計算。

範圍限定在批次。`wrongCount` 在 App 中只有四個顯示點（`BatchListView`、`BatchHomeView`、`GrammarBatchListView`、`GrammarBatchHomeView`），全都是批次聚合，使用者對這個數字的心智模型就是「這一批累計錯幾次」。按鈕放在 `BatchHomeView` 與 `GrammarBatchHomeView`，也就是把該數字當成主要資訊呈現的畫面。

重置經由 `Card` 與 `GrammarItem` 上新增的 `resetWrongCount()` 具名方法，與既有的 `recordWrong()` 對稱；`wrongCount` 的 `private(set)` 保護維持不變。重置不可復原，因此需經 `confirmationDialog` 確認，與專案其他不可復原操作一致。該批次累計為 0 時按鈕停用。

這個動作沒有行為副作用：`wrongCount` 不參與任何邏輯判斷，錯題複習的題目來源是當輪測驗答錯的卡片（由結果摘要傳入 `MistakeReviewView`），不讀取 `wrongCount`。歸零只改變顯示的數字。

替代方案一，做分組（deck）層級的一鍵歸零：否決，因為用批次逐一歸零已可達成，多出的是一組按鈕、確認文案與測試。

替代方案二，做單筆歸零（放在編輯畫面內）：否決，因為單獨清掉一個字的錯誤紀錄沒有實際使用情境。

替代方案三，把 `wrongCount` 改為可寫屬性讓 View 直接指派 0：否決，因為那等於讓任何地方都能悄悄改動練習紀錄，`private(set)` 的設計意圖會消失。

### 刪除單筆沿用既有的刪除鏈

編輯畫面提供「刪除這一筆」。刪除後的批次清理走與 `content-deletion` 完全相同的路徑：若該筆是批次的最後一筆，移除空批次並呼叫 `reindexBatches()` 重新編號，然後關閉編輯畫面與預習頁。

替代方案：只保留預習頁上的多選刪除，不在編輯畫面提供刪除。否決原因是使用者打開一筆內容、判定它該刪掉時，被迫關閉畫面、切到編輯模式、找回同一列、勾選、確認，是不必要的來回。

### 同步更新專案說明文件

`README.md`、`docs/architecture.md`、`docs/implementation.md` 目前都把內容描述為「匯入後即固定」。這個能力上線後三份文件都會與實際行為不符，需一併更新。容量改為 40 之後，這三份文件加上 `docs/getting-started.md`，以及兩個批次列表的空狀態文案，都還寫著舊的 50／20，同樣需要更新。

### 驗收不含模擬器互動操作

所有任務的驗收目標一律是三者的組合：**編譯通過**、**Model 層單元測試涵蓋該行為**、**程式碼審閱確認 UI 綁到正確的 Editor 函式或模型方法**。不要求任何人開模擬器點畫面。

這樣做的前提是：所有**有規則**的部分都已經下推到可測試的 Model 層 —— 欄位驗證、容量上限、`importOrder` 指派、空批次移除與批次重新編號、重置範圍，全部由 `CardEditorTests`、`GrammarItemEditorTests`、`ModelTests`、`GrammarModelTests` 覆蓋。View 層剩下的只是綁定。

明確接受的風險：sheet／提示視窗／`NavigationLink` 沒接上、文案錯字、版面破圖，這三類不會被自動化擋下。第一類已藉由改用 `NavigationLink`（見上）降低到「不會無聲失效」的程度，後兩類影響有限。

替代方案，建立 XCUITest target 覆蓋互動流程：否決。需要新增 target 並修改專案檔，維護成本與執行時間都高，對這個規模的專案不成比例。

## Implementation Contract

**Behavior**

單字側：

- 在單字預習頁非編輯模式下選取任一列，推入該卡片的編輯畫面，畫面預先填入該卡目前的 `word`、`partOfSpeech`、`translation`。
- 進入編輯模式後選取一列的語意是多選勾選，不會導航到編輯畫面。
- 儲存後，列表該列立即顯示新內容，該卡的 `wrongCount` 與 `importOrder` 不變。
- 在編輯畫面選擇刪除，該卡從批次移除；若它是批次最後一張卡，該批次一併移除、所屬 deck 的批次重新編號、預習頁關閉。
- 工具列「＋」以 sheet 開啟空白編輯畫面；儲存後新卡片接在該批次末端，`importOrder` 等於該批次現有最大 `importOrder` 加 1，`wrongCount` 為 0。
- 當批次已有 40 張卡，「＋」仍可按，按下後顯示提示視窗說明批次已滿並指引改用匯入功能，且不新增任何卡片、不建立任何批次。

文法側行為與單字側對稱，差別只在欄位（`question`、`correct`、3 個 `distractors`、`explanation`）。容量上限兩側同為 40。

錯誤次數重置（兩側對稱）：

- 批次首頁顯示「重算錯誤次數」。該批次所有項目的 `wrongCount` 加總大於 0 時可按，等於 0 時停用。
- 按下後出現確認對話框；確認後該批次每一個項目的 `wrongCount` 都變成 0。
- 批次首頁的「累計錯 N 次」隨即顯示 0，按鈕轉為停用；批次列表上該批次那一列同步顯示 0。
- 同一 deck 的其他批次的 `wrongCount` 不受影響。
- 項目的內容欄位、`importOrder`、批次歸屬、批次編號都不改變。

**Interface / data shape**

`CardEditor`（Model 層 enum，不涉及 UI）：

- `capacity`：常數，值為 `CardImporter.chunkSize`（40）。
- 驗證函式：輸入 `word`、`partOfSpeech`、`translation` 三個字串，回傳是否通過。通過條件為 `word` 與 `translation` 去除前後空白後皆非空；`partOfSpeech` 可為空。
- 是否可新增：輸入一個 `Batch`，回傳該批次卡片數是否小於 `capacity`。
- 新增：輸入 `Batch`、三個內容欄位與 `ModelContext`，建立 `Card` 並設定其 `batch`、插入 context，回傳建立的 `Card`。批次已滿或欄位不合法時不建立任何物件並回傳 nil。
- 更新：輸入既有 `Card` 與三個內容欄位，通過驗證後寫入內容欄位並回傳 true，不合法時不寫入任何值並回傳 false。不改動 `wrongCount` 與 `importOrder`。此函式讓「空的詞性存為 nil」這條正規化規則與新增路徑共用同一份實作，並留在可測試的 Model 層。
- 刪除：輸入 `Card` 與 `ModelContext`，刪除該卡；若批次因此清空，刪除批次並呼叫所屬 `Deck` 的 `reindexBatches()`。回傳批次是否被移除，供 View 決定是否關閉頁面。批次是否清空在刪除前判斷，因為 SwiftData 的關聯陣列不保證在 delete 當下同步更新。

`GrammarItemEditor` 與之對稱：

- `capacity` 值為 `GrammarItemImporter.chunkSize`（40，與單字側同值）。
- 驗證條件為 `question` 與 `correct` 去除前後空白後非空，且 `distractors` 恰有 3 個元素、每個去除前後空白後皆非空；`explanation` 可為空。
- 新增、刪除函式的形狀與單字側一致，操作對象為 `GrammarItem` 與 `GrammarBatch`。

`CardEditView` 與 `GrammarItemEditView`（SwiftUI View）：兩者皆支援編輯既有內容與新增兩種模式，具備「儲存」與「取消」，編輯既有內容時另有「刪除」。編輯既有內容由預習頁的 `NavigationLink` 推入；新增由工具列「＋」以 sheet 呈現。

`Card` 與 `GrammarItem`（既有 `@Model`）各新增一個無參數、無回傳值的 `resetWrongCount()` 實例方法，把自身的 `wrongCount` 設為 0。`wrongCount` 的 `private(set)` 宣告不變，外部仍無法直接指派。批次層級的重置由批次首頁對該批次的每一個項目逐一呼叫此方法完成，不新增 Model 層的批次級型別。

**Failure modes**

- 欄位不合法時「儲存」停用，不顯示錯誤紅字，也不寫入資料。使用者由停用狀態得知尚未填妥。
- 批次已滿時按「＋」顯示提示視窗並拒絕新增。這是有意讓使用者看見的阻擋，不是靜默失敗；「＋」本身不停用，否則使用者無從得知原因。
- 刪除採不可復原設計，與 `content-deletion` 一致，需經確認對話框。
- 取消編輯不寫入任何變更。
- 錯誤次數重置不可復原，需經確認對話框；取消確認時不改動任何 `wrongCount`。
- 批次累計錯誤次數為 0 時「重算錯誤次數」停用，避免使用者按下沒有效果的操作。

**Acceptance criteria**

`VocTestTests/CardEditorTests.swift` 覆蓋：

- 驗證通過與失敗的各種欄位組合，包含空白字串與只含空白的字串。
- 新增時 `importOrder` 等於現有最大值加 1，`wrongCount` 為 0。
- `capacity` 等於 40 且等於 `CardImporter.chunkSize`。
- 對已滿 40 張的批次新增，回傳 nil 且批次卡片數不變、不建立新批次。
- 刪除批次中唯一一張卡，批次被移除且 deck 剩餘批次編號連續由 1 起。
- 刪除多張卡中的一張，批次仍在，其餘卡片的 `importOrder` 不變。
- 修改內容後 `wrongCount` 與 `importOrder` 保持原值。

`VocTestTests/GrammarItemEditorTests.swift` 覆蓋對稱的案例，另加：干擾選項不足 3 個、超過 3 個或含空字串時驗證失敗；`capacity` 同樣以 40 驗證。

`VocTestTests/CardImporterTests.swift` 與 `VocTestTests/AcceptanceTests.swift` 的切批期望值改以 40 為基準，且不得再出現硬編碼的 50 或 20。

`VocTestTests/VocTestTests.swift` 的 `ModelTests` 新增覆蓋：呼叫 `Card.resetWrongCount()` 後 `wrongCount` 為 0；重置後再呼叫 `recordWrong()` 能從 0 重新累計；重置不改動 `word`、`partOfSpeech`、`translation`、`importOrder`。`VocTestTests/GrammarModelTests.swift` 覆蓋 `GrammarItem.resetWrongCount()` 的對稱案例。

View 層不做互動測試（見「驗收不含模擬器互動操作」決策）。改以程式碼審閱確認以下綁定：

- 兩個預習頁的每一列以 `NavigationLink` 推入對應的編輯畫面，且沒有任何自行判斷 `editMode` 的點選處理。
- 兩個預習頁的「＋」未加 `.disabled`，其 action 先檢查對應 Editor 的 `canAppend`，false 時顯示提示視窗並直接返回。
- 兩個編輯畫面的「儲存」`.disabled` 綁在對應 Editor 的 `isValid`，儲存路徑呼叫 Editor 的 update 或 append 而非直接寫欄位。
- 兩個編輯畫面的「刪除」經 `confirmationDialog` 後呼叫 Editor 的 delete，並以其回傳值決定是否關閉預習頁。
- 兩個批次首頁的「重算錯誤次數」經 `confirmationDialog` 後對批次內每個項目呼叫 `resetWrongCount()`，且按鈕在累計為 0 時停用。
- 專案中不再有硬編碼的批次容量數字，容量一律取自 `chunkSize`。

**Scope boundaries**

在範圍內：兩個編輯畫面、兩個 Model 層編輯器、兩個預習頁的入口與滿載提示視窗、批次容量統一為 40（含受影響的既有測試與文案）、`Card` 與 `GrammarItem` 的 `resetWrongCount()` 方法、兩個批次首頁的重置按鈕與確認對話框、對應單元測試、四份專案說明文件的同步更新。

不在範圍內：匯入解析器本身、測驗與錯題複習流程、批次列表與分組列表畫面的既有行為（除空狀態文案的數字）、資料模型的欄位結構、`content-deletion` 既有的多選刪除行為、分組層級與單筆層級與全 App 層級的錯誤次數重置、既有批次的重新切分，以及批次層級的 Markdown 貼上匯入。

## Risks / Trade-offs

- 使用者在所有批次都已滿時無法新增任何內容，只能改用匯入 → 這是選擇嚴格上限的已知代價。滿載提示視窗明確指引使用者改用匯入，讓阻擋是可理解而非死路。實務上一個 deck 的最後一批通常未滿，全滿只在總數恰為 40 的整數倍時發生。
- 容量由 50／20 改為 40 之後，既有測試中硬編碼的 50 與 20 會失敗 → 這是刻意讓它失敗：把期望值改為由 `chunkSize` 推導而非重寫成 40，可讓下次調整容量時不會再有一批測試要跟著改。
- 選取一列的行為在編輯模式與非編輯模式下不同（勾選對進入編輯頁），可能造成誤觸 → 這是 `List(selection:)` 加 `EditButton` 的內建語意，iOS 使用者熟悉；不額外設計互動。
- 兩側編輯器與編輯畫面各自獨立，規則變更時需同步改兩處 → 這是專案既有的對稱模式所帶來的一致代價；以兩份對稱的測試檔確保任一側漏改會被測試抓到。
- 編輯畫面直接以 `@Bindable` 綁定 SwiftData 模型，取消時已輸入的字元可能已寫進模型 → 編輯畫面改為先綁定本地暫存狀態，按下儲存時才寫回模型，避免取消後仍留下變更。
- 驗收不含模擬器互動，UI 綁定錯誤（sheet／提示視窗／`NavigationLink` 沒接上、文案錯字、版面破圖）不會被自動化擋下 → 綁定改用不會無聲失效的內建機制（`NavigationLink` 取代自訂手勢），其餘以逐項的程式碼審閱清單涵蓋，清單列在上方 Acceptance criteria。
- 錯誤次數重置不可復原，誤觸會永久失去該批次的練習紀錄 → 以確認對話框擋一層，並在累計為 0 時停用按鈕，減少無意義的觸發機會。
- 新增 `resetWrongCount()` 之後，`wrongCount` 不再是嚴格單調遞增，既有測試 `testWrongCountIsMonotonicViaRecordWrong` 的命名會與新行為產生語意落差 → 保留該測試不動（它驗證的是 `recordWrong()` 本身仍只增不減，這點不變），重置行為以新增的獨立測試覆蓋。
- 這個 change 的任務數量因併入重置而增加至 18 項，超過 Spectra 建議的 15 項上限 → 任務分組維持獨立（重置自成一組，不與編輯任務交錯），必要時可先完成第 1 至 3 組並中途 park。
