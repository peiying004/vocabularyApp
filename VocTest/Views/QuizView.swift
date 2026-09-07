import SwiftUI

/// 單字測驗頁：逐題顯示單字提示與選項，答題後給予對錯回饋，
/// 全部作答完畢後切換為 ResultView 顯示本輪結果。
struct QuizView: View {
    /// 測驗流程狀態機（目前題目、進度、作答與結果計算）。
    @State var session: QuizSession
    let batch: Batch
    /// 是否為錯題複習模式，影響標題文字。
    let isMistakeQuiz: Bool

    /// 目前題目的選項文字（含正解與干擾項）。
    @State private var currentChoices: [String] = []
    /// 作答後的回饋（答對／答錯並顯示正解）；為 nil 表示尚未作答。
    @State private var feedback: AnswerFeedback?
    /// 測驗結束後的結果摘要；非 nil 時切換為結果畫面。
    @State private var finishedSummary: ResultSummary?
    /// 已選但尚未送出的答案，於按「下一題」時才真正提交給 session。
    @State private var pendingChoice: Choice?

    private var prompt: String {
        guard let card = session.currentCard else { return "" }
        if let pos = card.partOfSpeech, !pos.isEmpty {
            return "\(card.word) (\(pos))"
        }
        return card.word
    }

    var body: some View {
        Group {
            if let summary = finishedSummary {
                ResultView(
                    summary: summary,
                    batch: batch,
                    isMistakeQuiz: isMistakeQuiz
                )
            } else if session.currentCard != nil {
                quizContent
            }
        }
        .navigationTitle(finishedSummary != nil ? "結果" : (isMistakeQuiz ? "錯題複習" : "測驗"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshChoices() }
    }

    private var quizContent: some View {
        VStack(spacing: 24) {
            Text(prompt)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            if let feedback = feedback {
                feedbackBanner(feedback)
            }

            VStack(spacing: 12) {
                ForEach(currentChoices, id: \.self) { choice in
                    Button {
                        submit(.translation(choice))
                    } label: {
                        Text(choice)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .disabled(feedback != nil)
                }
            }
            .padding(.horizontal)

            if feedback == nil {
                Button {
                    submit(.dontKnow)
                } label: {
                    Text("我不會")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
                .padding(.horizontal)
            } else {
                Button {
                    advance()
                } label: {
                    Text("下一題")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func refreshChoices() {
        currentChoices = session.choicesForCurrent()
    }

    private func submit(_ choice: Choice) {
        // 先在本地判斷對錯並顯示回饋，但暫不推進 session；
        // 實際提交與進度推進延後到 advance()。
        guard let card = session.currentCard else { return }
        let correctTranslation = card.translation
        let isCorrect: Bool
        switch choice {
        case .translation(let t) where t == correctTranslation:
            isCorrect = true
        case .translation, .dontKnow:
            isCorrect = false
        }
        pendingChoice = choice
        feedback = isCorrect ? .correct(answer: correctTranslation) : .wrong(correct: correctTranslation)
    }

    private func advance() {
        // 提交暫存的答案並前進：若已是最後一題則產生結果摘要，
        // 否則刷新下一題的選項。
        if let choice = pendingChoice {
            _ = session.submit(choice)
        }
        pendingChoice = nil
        feedback = nil
        if session.isFinished {
            finishedSummary = session.resultSummary()
        } else {
            refreshChoices()
        }
    }

    @ViewBuilder
    private func feedbackBanner(_ f: AnswerFeedback) -> some View {
        switch f {
        case .correct(let answer):
            VStack(spacing: 4) {
                Text("答對")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("正解：\(answer)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        case .wrong(let correct):
            Text("正解：\(correct)")
                .font(.headline)
                .foregroundStyle(.red)
        }
    }
}

enum AnswerFeedback: Equatable {
    case correct(answer: String)
    case wrong(correct: String)
}

extension ResultSummary: Hashable {
    public static func == (lhs: ResultSummary, rhs: ResultSummary) -> Bool {
        lhs.correctCount == rhs.correctCount &&
        lhs.wrongTaps == rhs.wrongTaps &&
        lhs.mistakeCards.map(\.persistentModelID) == rhs.mistakeCards.map(\.persistentModelID)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(correctCount)
        hasher.combine(wrongTaps)
        hasher.combine(mistakeCards.map(\.persistentModelID))
    }
}
