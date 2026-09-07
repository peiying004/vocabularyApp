## Summary

答對測驗題時，於綠字「答對」下方新增一行灰色「正解：xxx」，顯示使用者剛選對的答案。

## Motivation

目前答對時只顯示綠字「答對」，選項會被停用且不會標示哪個是正解。使用者若一時忘記自己剛選了哪個答案，就無法在進入下一題前確認自己猜對的內容。答錯時系統已會顯示紅字正解，答對時卻沒有對應資訊，形成落差。

## Proposed Solution

- 為共用的 `AnswerFeedback` enum 的 `.correct` case 加上關聯值 `answer: String`。
- 單字測驗與文法測驗兩處答對時，將正解字串帶入回饋（單字用 `card.translation`，文法用 `item.correct`）。
- 兩處回饋顯示的 `.correct` 分支改為上下兩行：第一行維持綠色「答對」，第二行以灰色（次要色）顯示「正解：\(answer)」。
- 答錯（`.wrong`）分支完全不變，維持紅字「正解：xxx」。

## Non-Goals

- 不變更答錯情境的顯示與行為。
- 不變更錯題複習頁（該頁不顯示對錯回饋）。
- 不變更計分、題目推進或選項生成邏輯。

## Impact

- Affected specs: quiz-review（新增答對時揭示正解的需求）
- Affected code:
  - Modified:
    - VocTest/Views/QuizView.swift
    - VocTest/Views/GrammarQuizView.swift
