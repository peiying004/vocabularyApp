import SwiftUI

/// 文法錯題整理頁：列出本輪答錯的題目，並可用這些錯題重新開啟一輪錯題複習測驗。
struct GrammarMistakeReviewView: View {
    /// 由結果摘要傳入、用來組成複習測驗的錯題題目。
    let mistakeItems: [GrammarItem]
    let batch: GrammarBatch

    private var sortedItems: [GrammarItem] {
        mistakeItems.sorted { $0.importOrder < $1.importOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(sortedItems) { item in
                GrammarItemRow(item: item)
            }
            NavigationLink {
                // 以錯題題目建立專屬的複習測驗（isMistakeQuiz 標記為 true）。
                GrammarQuizView(
                    session: GrammarMistakeQuiz.session(from: sortedItems, in: batch),
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
