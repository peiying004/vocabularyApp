## 1. 擴充回饋型別

- [x] 1.1 修改共用的 `AnswerFeedback` enum（定義於 VocTest/Views/QuizView.swift），將 `.correct` case 由無關聯值改為 `case correct(answer: String)`。變更後 enum 仍為 `Equatable`，且不影響 `.wrong(correct:)` case。

## 2. 單字測驗顯示答對正解

- [x] 2.1 在 VocTest/Views/QuizView.swift 的 `submit(_:)` 中，答對分支改為 `feedback = .correct(answer: correctTranslation)`。
- [x] 2.2 在 VocTest/Views/QuizView.swift 的 `feedbackBanner(_:)` 的 `.correct` 分支，改為上下兩行：第一行維持綠色「答對」（`.foregroundStyle(.green)`），第二行以次要色顯示「正解：\(answer)」（`.foregroundStyle(.secondary)`）。`.wrong` 分支維持不變。

## 3. 文法測驗顯示答對正解

- [x] 3.1 在 VocTest/Views/GrammarQuizView.swift 的 `submit(_:)` 中，答對分支改為 `feedback = .correct(answer: correct)`。
- [x] 3.2 在 VocTest/Views/GrammarQuizView.swift 的 `feedbackBanner(_:)` 的 `.correct` 分支，改為與單字測驗一致的兩行顯示（綠色「答對」+ 次要色「正解：\(answer)」）。`.wrong` 分支與既有解析（explanation）顯示維持不變。

## 4. 驗證

- [x] 4.1 建置 App（xcodebuild 或 Xcode）確認無編譯錯誤，特別是 `.correct` 加關聯值後所有引用點皆已更新。
- [x] 4.2 驗收「Correct Answer Reveal On Correct Response」，全程不開模擬器操作畫面（本專案的驗收標準不含模擬器互動）。以程式碼審閱確認四項：(a) `QuizView` 與 `GrammarQuizView` 的 `feedbackBanner(_:)` 在 `.correct` 分支以 `VStack` 呈現上下兩行，第一行為「答對」且 `.foregroundStyle(.green)`，第二行為「正解：」加上答案且 `.foregroundStyle(.secondary)`；(b) 兩處 `feedbackBanner(_:)` 的實作逐字相同（以 diff 比對兩個區塊無差異）；(c) 兩處 `.wrong` 分支維持單行紅字「正解：」加上答案，不含任何「答對」文字；(d) 兩處 `submit(_:)` 答對時帶入的字串分別為該卡的 `translation` 與該題的 `correct`，對應 spec Example 中 `apple` / `蘋果` 的預期輸出。驗證：`xcodebuild build -scheme VocTest` 通過；`xcodebuild test` 全綠（無 failure，確認既有測驗流程無回歸）；上述四項逐項在程式碼中確認。
