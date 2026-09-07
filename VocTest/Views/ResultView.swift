import SwiftUI

/// 測驗結果頁：顯示本輪答對／答錯統計；若有錯題，可導向錯題整理，
/// 或返回批次首頁。
struct ResultView: View {
    /// 本輪測驗結果摘要（答對數、答錯數與錯題卡片清單）。
    let summary: ResultSummary
    let batch: Batch
    /// 是否為錯題複習模式，影響標題文字。
    let isMistakeQuiz: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(isMistakeQuiz ? "錯題複習結果" : "本輪結果")
                    .font(.title2.bold())

                HStack(spacing: 32) {
                    VStack {
                        Text("\(summary.correctCount)").font(.system(size: 48, weight: .bold)).foregroundStyle(.green)
                        Text("答對").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack {
                        Text("\(summary.wrongTaps)").font(.system(size: 48, weight: .bold)).foregroundStyle(.red)
                        Text("答錯（含我不會）").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 48)

            Spacer()

            if summary.wrongTaps > 0 {
                NavigationLink {
                    MistakeReviewView(mistakeCards: summary.mistakeCards, batch: batch)
                } label: {
                    Text("看錯題")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            Button("回到批次首頁") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
    }
}
