# 開始使用

> ← 回到 [專案首頁](../README.md)

本文件說明如何安裝、執行 VocTest，以及匯入題目的 Markdown 格式。

- [安裝與執行](#安裝與執行)
- [匯入格式](#匯入格式)

---

## 安裝與執行

### 環境需求

| 項目 | 需求 |
|------|------|
| 作業系統 | macOS（建議 Ventura 13 以上） |
| 開發工具 | Xcode 15 以上（內含 iOS 17 SDK 與模擬器） |
| 執行目標 | iOS 17.0 以上（模擬器或實機皆可） |

> SwiftData 需要 iOS 17 SDK，因此 Xcode 版本需為 15 以上。

### 步驟一：取得專案

```bash
# 若已放上 GitHub，clone 下來：
git clone <你的-repository-網址>
cd voctest
```

或直接下載專案資料夾。

### 步驟二：用 Xcode 開啟

```bash
# 在專案根目錄執行，會用 Xcode 開啟專案
open VocTest.xcodeproj
```

或在 Xcode 中選 **File ▸ Open…**，選取 `VocTest.xcodeproj`。

### 步驟三：選擇 Scheme 與模擬器

1. 確認左上角 Scheme 為 **VocTest**。
2. 執行目標（Scheme 右側）選一台 iOS 17+ 模擬器，例如 **iPhone 16**。

### 步驟四：建置並執行

- 按 **⌘R**（或點 ▶︎ Run），Xcode 會建置並在模擬器啟動 App。
- 執行單元測試：按 **⌘U**，或用指令列：

```bash
xcodebuild test -project VocTest.xcodeproj -scheme VocTest \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 步驟五：在實機上執行（選用）

1. 用傳輸線接上 iPhone，並在執行目標選單選擇該裝置。
2. 在 **Signing & Capabilities** 頁選一個開發者團隊（免費 Apple ID 亦可）。
3. 按 **⌘R** 安裝到手機；首次執行需在手機「設定 ▸ 一般 ▸ VPN 與裝置管理」信任開發者憑證。

### 首次使用

1. 第一次啟動會在首頁上先看到一張 4 頁的教學卡；按最後一頁的 **開始使用** 或右上角 **X** 關閉，之後不再自動出現。想重看時按首頁右上角的問號按鈕。
2. 進入對應模式（單字或文法）後，先用右上角 **＋** 建立一個分組。
3. 進入分組 → 點右上角匯入圖示 → 貼上 Markdown 或選檔匯入（格式見下方 [匯入格式](#匯入格式)）。
4. 點任一批次進入批次首頁，選 **先複習所有單字** 或 **直接開始測驗**（文法路線對應的按鈕是 **先預習所有題目** 與 **直接開始測驗**）。

---

## 匯入格式

### 單字（2 或 3 欄）

支援 Markdown 表格，表頭列與分隔列會自動略過；YAML front-matter、標題等非表格行不會被匯入，而是列為「無效行」並附上行號，其餘表格行照常匯入：

```markdown
| 單字        | 詞性 | 翻譯       |
| ----------- | ---- | ---------- |
| accommodate | v.   | 容納、適應 |
| itinerary   | n.   | 行程表     |
| brief       |      | 簡短的     |
```

### 文法（4 欄）

`distractors` 欄以逗號分隔三個誘答選項，`explanation` 可留空：

```markdown
| question              | correct | distractors        | explanation      |
| --------------------- | ------- | ------------------ | ---------------- |
| I ___ to school daily.| go      | goes, going, gone  | 主詞 I 用原形    |
```

匯入後：單字與文法都每 40 筆自動切成一批；無法解析的行會在畫面上列出行號供修正。

---

> 想了解程式如何解析與切批？見 [核心實作](implementation.md)。
> 想了解整體架構？見 [架構設計](architecture.md)。
