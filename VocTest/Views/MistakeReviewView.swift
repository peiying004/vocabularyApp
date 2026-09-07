import SwiftUI

/// 錯題整理頁：列出本輪答錯的卡片，並可用這些錯題重新開啟一輪錯題複習測驗。
struct MistakeReviewView: View {
    /// 由結果摘要傳入、用來組成複習測驗的錯題卡片。
    let mistakeCards: [Card]
    let batch: Batch

    private var sortedCards: [Card] {
        mistakeCards.sorted { $0.importOrder < $1.importOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(sortedCards) { card in
                CardListRow(card: card)
            }
            NavigationLink {
                // 以錯題卡片建立專屬的複習測驗（isMistakeQuiz 標記為 true）。
                QuizView(
                    session: MistakeQuiz.session(from: sortedCards, in: batch),
                    batch: batch,
                    isMistakeQuiz: true
                )
            } label: {
                Text("開始錯題複習")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("錯題整理")
        .navigationBarTitleDisplayMode(.inline)
    }
}
