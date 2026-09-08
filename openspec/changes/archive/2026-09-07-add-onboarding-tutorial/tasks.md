## 1. 教學內容與示意圖

- [x] 1.1 定義四頁教學內容的靜態資料來源，滿足 `Tutorial Page Content And Paging` 對頁數與標題的規定：在 `VocTest/Views/OnboardingPage.swift` 建立一個具備 `Identifiable` 的頁面結構與一個長度為 4 的靜態常數陣列，四頁標題依序為 `兩條學習路線`、`貼上就能出題`、`四選一測驗`、`答錯會再問一次`，每頁另含標題文字、四行左右的說明文字、與示意圖識別方式；第 2 頁提及批次大小 40 之處加註來源註解。驗證：完成後對照 design.md 的「四頁內容」表格逐欄核對標題與說明重點。
- [x] 1.2 依決策「以 SwiftUI 繪製向量示意圖，而非使用螢幕截圖」產出四張示意圖：在 `VocTest/Views/OnboardingIllustrations.swift` 以 `RoundedRectangle`、`Text`、`Image(systemName:)` 等 SwiftUI 原生元件疊出四張圖（兩張並列路線卡片、表格轉批次卡片堆、四選一含正解標記、錯題繞回隊尾的循環箭頭），全部使用語意色彩以自動跟隨深淺色模式，且不新增任何圖片資產到 `VocTest/Assets.xcassets`。驗證：於 Xcode Preview 逐一預覽四張圖，並確認 asset catalog 內容未變動。

## 2. 遮罩容器與分頁

- [x] 2.1 建立教學遮罩容器並滿足 `First-Launch Tutorial Overlay` 的呈現與點擊攔截規定：在 `VocTest/Views/OnboardingOverlayView.swift` 實作半透明遮罩，底下首頁隱約可見但所有觸控事件被遮罩吸收，中央置入單張卡片容器。驗證：於 Xcode Preview 疊在 HomeView 上確認首頁可見；並在模擬器點擊首頁「單字」按鈕位置確認不觸發導航。
- [x] 2.2 讓卡片支援雙向左右滑動翻頁並顯示頁次，完成 `Tutorial Page Content And Paging` 的分頁行為：以 `TabView` 搭配 `.tabViewStyle(.page)` 綁定 1.1 的四頁陣列，卡片底部顯示頁面指示器並反映目前頁次，每頁由示意圖、標題、說明文字三段組成。驗證：模擬器上從第 1 頁左滑到第 4 頁再右滑回第 1 頁，確認頁面指示器每一步都同步。
- [x] 2.3 實作 `Tutorial Exit Paths And Persistence` 的兩個結束控制項，落實決策「兩條結束出口寫同一個旗標」：卡片右上角的關閉按鈕在四頁皆可用，第 4 頁的「開始使用」按鈕結束教學，兩者觸發同一個結束流程（關閉遮罩並回報「已完成」給呼叫端）。關閉與結束按鈕的點擊區必須位於遮罩之上，避免出現關不掉的死鎖。驗證：模擬器上分別在第 1、2、4 頁測試關閉按鈕、以及第 4 頁的結束按鈕，四次都能正常關閉遮罩。
- [x] 2.4 依決策「每頁都放主按鈕以固定卡片高度」讓卡片底部固定位置永遠有一顆主按鈕：前三頁顯示「下一步」並前進一頁，第 4 頁顯示「開始使用」並結束教學，按鈕位置與卡片高度在四頁之間不變。驗證：模擬器逐頁截圖比對四頁的卡片頂緣座標一致，並以「下一步」從第 1 頁按到第 4 頁確認每次都正確前進。

## 3. 掛載、旗標與重看入口

- [x] 3.1 依決策「以 AppStorage 旗標判斷首次啟動，而非以資料庫是否為空判斷」接上持久化並掛載遮罩，同時滿足決策「以 overlay 掛在 ContentView，而非 fullScreenCover 或 sheet」：在 `VocTest/ContentView.swift` 以 `.overlay` 把教學疊在 `NavigationStack` 之上，用 `@AppStorage("hasSeenOnboarding")`（`Bool`，預設 `false`）決定首次啟動是否自動顯示，並在自動顯示路徑的結束流程把旗標設為 `true`。驗證：模擬器刪除 App 後重裝，首次開啟自動出現教學；結束後重開 App 不再出現。
- [x] 3.2 依決策「重看入口放在 Home shell 的 toolbar」實作 `Tutorial Replay Entry Point`，並使 `Home Shell As App Root` 新增的說明控制項成立：在 `VocTest/Views/HomeView.swift` 的 trailing toolbar 位置加入問號按鈕，點擊後開啟同一份教學遮罩且一律停在第 1 頁，此路徑結束時不改動 `hasSeenOnboarding`，也不推入任何導航畫面。驗證：模擬器上在旗標已為 `true` 的狀態按問號，教學從第 1 頁出現、關閉後重開 App 仍不自動顯示，且過程中未發生導航。

## 4. 測試與驗收

- [x] 4.1 建立教學內容的單元測試，確保四頁定義不會被誤改：在 `VocTestTests/OnboardingTests.swift` 撰寫測試，斷言頁面陣列恰有 4 個元素、每個元素的標題與說明文字皆非空字串、且標題依序為 `兩條學習路線`、`貼上就能出題`、`四選一測驗`、`答錯會再問一次`。測試不得讀寫 `UserDefaults.standard`，以免污染其他測試。驗證：在 Xcode 執行 `OnboardingTests` 全數通過。
- [x] 4.2 完成旗標行為的手動驗收矩陣：重裝 App 後（a）滑到第 4 頁按結束、（b）重裝後在第 2 頁按叉叉，兩種情況重開 App 都不再自動顯示教學；（c）按首頁問號可再次開啟並停在第 1 頁。驗證：三條路徑逐一在模擬器實測並記錄結果。
- [x] 4.3 確認教學在深色模式與最小支援機型上皆可讀：於淺色與深色模式下檢視四頁的卡片、示意圖與文字對比度，並在 iPhone SE 尺寸確認示意圖未溢出、說明文字在必要時可捲動。驗證：兩種外觀模式各走完四頁，於 iPhone SE 模擬器目視確認無截斷。
- [x] 4.4 確認本次改動未破壞既有行為：執行專案既有的 `VocTestTests` 全套測試。驗證：所有既有測試維持通過，且未修改任何 SwiftData model、Parser 或 ReviewEngine 檔案。
