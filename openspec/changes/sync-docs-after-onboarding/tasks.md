## 1. architecture.md 的圖與結構

- [x] 1.1 依 design「架構圖新增 App 殼層子圖而不是把教學塞進 View 層」，在 docs/architecture.md 的分層架構 mermaid 圖最上方加入 subgraph「App 殼層」，含 ContentView、OnboardingOverlayView、UserDefaults hasSeenOnboarding 三個節點，殼層以一條箭頭連到 HomeView，教學相關箭頭只在殼層內；同段落的「怎麼看這張圖」說明改為四層。滿足 spec「Architecture Diagram Includes The App Shell」。驗證：內容審閱確認 UserDefaults 節點不在 Model subgraph 內，並在 mermaid live editor 貼上該區塊確認能渲染。
- [x] 1.2 依 design「操作流程圖拆成主流程與內容管理兩張」，把 docs/architecture.md 的「使用者操作流程」改成主流程圖：加入已看過教學判斷、教學遮罩、首頁重看教學、批次首頁的「先複習所有單字」與「直接開始測驗」、結果頁「看錯題」到錯題整理清單、「開始錯題複習」回測驗、「回到批次首頁」回批次首頁；圖下註明從預習清單進入測驗時會回到預習清單。滿足 spec「User Flow Diagrams Match View Navigation」的結果回退與錯題整理場景。驗證：內容審閱確認結果節點沒有任何箭頭指向分組列表，且每個箭頭文字能在 BatchHomeView、ResultView、MistakeReviewView 找到相同按鈕文字。
- [x] 1.3 依 design「操作流程圖拆成主流程與內容管理兩張」，在主流程圖之後新增內容管理流程圖並移除原本獨立的「編輯模式多選刪除」圖：以預習清單為起點，涵蓋點列進編輯頁與儲存、＋後的批次已滿判斷、「手動輸入一筆」與「貼上 Markdown」選單、貼上超量的「開新批次」與「放棄此次新增」、多選刪除確認、空批次移除與 reindexBatches。同步更新該圖的「怎麼看這張圖」說明。滿足 spec「User Flow Diagrams Match View Navigation」的四條新增路徑場景。驗證：內容審閱對照 PreviewView、BatchImportView、CardEditView 的 Menu 與 confirmationDialog 文字，逐一勾稽箭頭標籤；mermaid live editor 確認能渲染。
- [x] 1.4 讓 docs/architecture.md 的專案結構樹反映實際檔案：補上 ContentView.swift、VocTestApp.swift、Views 底下的 OnboardingOverlayView、OnboardingPage、OnboardingIllustrations，以及 MistakeReviewView 與 GrammarMistakeReviewView；「設計取捨」新增一條說明教學已看過旗標存 UserDefaults 而非用資料庫是否為空判斷。滿足 spec「Documentation Describes The First-Launch Tutorial」的專案結構場景。驗證：對樹中列出的每個檔名執行 ls VocTest/Views 與 ls VocTest 比對，全部存在。

## 2. README 的敘述修正與精簡圖

- [x] 2.1 依 design「front-matter 敘述改為如實描述而不改程式」，把 README.md 功能總覽「容錯解析」bullet 改為 front-matter 等非表格行會列為無效行並跳過、其餘表格行照常匯入；「自動切批」bullet 刪除「不會自動溢位到別批或另開新批」，改為批次已滿時需經使用者同意才開新批次；「四選一測驗」bullet 註明同批抽取只適用單字路線、文法題用題目自帶的 distractors。滿足 spec「Documentation Statements Match Parser And Batch Behavior」。驗證：grep -n "自動略過 YAML" README.md 與 grep -n "不會自動溢位" README.md 皆無結果，且 MarkdownParserTests 的 testDashOnlyLineWithoutPipeIsNotSeparator 描述的行為與新文字一致。
- [x] 2.2 在 README.md 功能總覽新增一個 bullet 描述首次啟動教學：首次啟動疊在首頁上、共 4 頁、最後一頁「開始使用」或右上角 X 關閉、首頁右上角問號按鈕可重看。滿足 spec「Documentation Describes The First-Launch Tutorial」的 README 場景。驗證：內容審閱對照 OnboardingOverlayView 的按鈕文字「開始使用」「下一步」與 HomeView 的 accessibilityLabel「查看使用教學」。
- [x] 2.3 依 design「README 放精簡版圖並連到完整版」，在 README.md 文件導覽之後新增「架構與流程一覽」小節：一張精簡架構圖（App 殼層、View、純邏輯、Model、UserDefaults、SwiftData 共 6 個節點）與一張精簡主流程圖（首頁、分組、批次、測驗、結果、錯題複習共 6 個節點），每張圖下方一行連結到 docs/architecture.md 的對應標題錨點。滿足 spec「README Contains Condensed Diagrams」。驗證：grep -c '```mermaid' README.md 為 2，人工數每張圖節點不超過 10 個，點擊錨點連結能跳到 architecture.md 對應段落。

## 3. getting-started.md 與 implementation.md

- [x] 3.1 依 design「front-matter 敘述改為如實描述而不改程式」，把 docs/getting-started.md 匯入格式段落的「YAML front-matter 與標題列會自動略過」改為表頭列與分隔列自動略過、front-matter 等非表格行會列為無效行；「首次使用」步驟開頭加入首次啟動先看到 4 頁教學與關閉方式，並把「點任一批次即可開始測驗」改為點批次進入批次首頁後選「先複習所有單字」或「直接開始測驗」。滿足 spec「Documentation Describes The First-Launch Tutorial」的 getting-started 場景與「Documentation Statements Match Parser And Batch Behavior」。驗證：grep -n "自動略過" docs/getting-started.md 只剩描述表頭與分隔列的句子；步驟文字與 BatchHomeView 的兩個 Label 文字一致。
- [x] 3.2 依 design「每一處修正都對應到具體檔案或畫面文字」，修正 docs/implementation.md：測驗狀態機 mermaid 圖的「點『不知道』」改為「點『我不會』」；第 2 節 MarkdownParser 範例的 case 2 分支補上 word 與 translation 的非空 guard 並在範例前註明省略了空白行、分隔列、表頭列的略過邏輯；「測試」段落的涵蓋範圍補上 OnboardingTests（教學頁數、標題順序、chunkSize 文案）與 AcceptanceTests（匯入切批到測驗結束的端對端場景）。滿足 spec「Documentation Statements Match Parser And Batch Behavior」的狀態機場景與「Documentation Describes The First-Launch Tutorial」的測試涵蓋要求。驗證：grep -n "不知道" docs/implementation.md 無結果；範例 case 2 與 VocTest/Parser/MarkdownParser.swift 的 case 2 guard 條件相同；ls VocTestTests 確認兩個測試檔存在。

## 4. 整體勾稽

- [x] 4.1 依 design「每一處修正都對應到具體檔案或畫面文字」做最後一輪全文比對：把四份文件中每一個引號內的畫面文字（按鈕、對話框、標題）用 grep 在 VocTest/Views 找到相同字串，把每一個提到的檔名用 ls 確認存在，把每一個提到的數字（批次 40、間隔 3、教學 4 頁、iOS 17.0）對照 CardImporter.chunkSize、QuizSession.submit 的 gap、OnboardingPage.all.count、project.pbxproj 的 IPHONEOS_DEPLOYMENT_TARGET。驗證：整理成一張「文件文字 → 程式來源」對照表附在 change 的 tasks 完成紀錄中，沒有任何一列找不到來源。
- [x] 4.2 確認四份文件裡所有 mermaid 區塊都能渲染且沒有殘留舊圖：docs/architecture.md 應有分層架構圖、資料模型圖、主流程圖、內容管理流程圖共 4 個 mermaid 區塊，README.md 2 個，docs/implementation.md 1 個。驗證：grep -c '```mermaid' 對三個檔案分別得到 4、2、1，並把每個區塊貼到 mermaid live editor 確認無語法錯誤。

## 勾稽紀錄（task 4.1，2026-09-30）

畫面文字：四份文件中引號或粗體內的按鈕、對話框、區塊文字，逐一用 grep 在 VocTest/Views 找到相同的 Swift 字串常值。

| 文件文字 | 出現在 | 程式來源 |
| -------- | ------ | -------- |
| 開始使用 / 下一步 / 右上角 X | README、getting-started | OnboardingOverlayView.swift 的 primaryButton 與 closeButton |
| 首頁右上角問號按鈕（查看使用教學） | README、getting-started、architecture | HomeView.swift 的 toolbar Button 與 accessibilityLabel |
| 先複習所有單字 / 直接開始測驗 | getting-started、architecture | BatchHomeView.swift 的兩個 Label |
| 先預習所有題目 | getting-started | GrammarBatchHomeView.swift 的 Label |
| 開始測驗 | architecture | PreviewView.swift、GrammarPreviewView.swift |
| 看錯題 / 回到批次首頁 | architecture、README 精簡圖 | ResultView.swift、GrammarResultView.swift |
| 開始錯題複習 | architecture、README 精簡圖 | MistakeReviewView.swift、GrammarMistakeReviewView.swift |
| 我不會 | implementation 狀態機圖 | QuizView.swift、GrammarQuizView.swift 的 Button |
| 手動輸入一筆 / 貼上 Markdown | README、architecture | PreviewView.swift 的 Menu 與 confirmationDialog |
| 開新批次 / 放棄此次新增 | README、architecture | BatchImportView.swift、GrammarBatchImportView.swift 的 confirmationDialog；PreviewView.swift 的批次已滿對話框 |
| 刪除這一筆（刪除這張卡 / 刪除這一題） | architecture | CardEditView.swift、GrammarItemEditView.swift |
| 無效行 | README、getting-started | ImportView.swift、BatchImportView.swift 的 Section 標題「無效行（已跳過）」 |
| 重算錯誤次數 | architecture、implementation | BatchHomeView.swift、GrammarBatchHomeView.swift |

檔名：專案結構樹與測試段落提到的 VocTestApp.swift、ContentView.swift、OnboardingOverlayView、OnboardingPage、OnboardingIllustrations、MistakeReviewView、GrammarMistakeReviewView、BatchHomeView、PreviewView、OnboardingTests、AcceptanceTests 以 ls 全部確認存在。

數字：

| 文件數字 | 程式來源 |
| -------- | -------- |
| 批次大小 40 | CardImporter.chunkSize 與 GrammarItemImporter.chunkSize 皆為 40 |
| 答錯重排間隔 3 | QuizSession.submit 與 GrammarQuizSession.submit 的 gap = min(remaining.count, 3) |
| 教學 4 頁 | OnboardingPage.all 有 4 個元素 |
| iOS 17.0 / Swift 5 | project.pbxproj 的 IPHONEOS_DEPLOYMENT_TARGET = 17.0、SWIFT_VERSION = 5.0 |

mermaid（task 4.2）：本機沒有 Node 與 mermaid CLI，未能用 live editor 實際渲染；改以語法檢查腳本確認每個區塊的 subgraph/end 配對、方括號與圓括號配對、邊標籤的管線符號成對、方框節點文字不含半形括號，7 個區塊全部通過。
