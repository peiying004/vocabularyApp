## Why

VocTest 的核心價值是「貼上 Markdown 表格 → 立刻變成可測驗的題庫 → 答錯的題目重點複習」，但初次打開 App 只會看到 `單字` 與 `文法` 兩顆按鈕，資料庫是空的，畫面上沒有任何線索說明這條流程存在。新使用者必須自己摸索或去翻 README 才知道要做什麼。需要一個在首次啟動時出現的簡短教學，用四頁說完「這個 App 在幹嘛」。

## What Changes

- 新增首次啟動教學：以半透明遮罩浮在首頁之上的卡片，可左右滑動翻頁，共 4 頁。
- 每頁包含一張以 SwiftUI 繪製的向量示意圖、一個標題、與約四行說明文字。
- 教學卡片右上角提供關閉按鈕（叉叉），使用者可在任何一頁提早結束。
- 最後一頁提供「開始使用」按鈕結束教學。
- 提早關閉與看完結束兩條出口，都會把「已看過教學」旗標寫成已看過，下次啟動不再自動顯示。
- 首頁 toolbar 右上角新增說明按鈕（問號），可隨時重新開啟教學；經此入口開啟不會改動已看過旗標。
- 遮罩會攔截點擊，教學顯示期間首頁不可操作。

## Capabilities

### New Capabilities

- `onboarding`: 首次啟動教學的顯示時機、分頁內容、兩條結束出口、已看過旗標的持久化，以及重看入口的行為。

### Modified Capabilities

- `app-home`: Home shell 目前規定只呈現兩顆入口按鈕。本次在其 toolbar 增加一個說明按鈕作為教學重看入口，需擴充該 spec 對 Home shell 組成的描述。

## Impact

- Affected specs:
  - 新增 `onboarding`
  - 修改 `app-home`
- Affected code:
  - New:
    - `VocTest/Views/OnboardingOverlayView.swift`（遮罩容器、分頁 TabView、關閉按鈕、頁面指示器）
    - `VocTest/Views/OnboardingPage.swift`（單頁資料模型與四頁內容定義）
    - `VocTest/Views/OnboardingIllustrations.swift`（四張 SwiftUI 繪製示意圖）
    - `VocTestTests/OnboardingTests.swift`（教學內容與旗標行為的單元測試）
  - Modified:
    - `VocTest/ContentView.swift`（掛載教學遮罩、依旗標決定初次是否顯示）
    - `VocTest/Views/HomeView.swift`（toolbar 新增說明按鈕）
  - Removed: （無）
- 不引入任何第三方套件，不新增圖片資產，不改動任何 SwiftData model 或既有測驗邏輯。
