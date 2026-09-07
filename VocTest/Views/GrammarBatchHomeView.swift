import SwiftData
import SwiftUI

/// 文法批次首頁：單一批次的入口，顯示題數與累計錯誤次數，
/// 提供兩條路徑——先進 GrammarPreviewView 預習所有題目，或直接進 GrammarQuizView 開始填空四選一測驗；
/// 另可把該批次的累計錯誤次數歸零。
struct GrammarBatchHomeView: View {
    let batch: GrammarBatch
    @Environment(\.modelContext) private var modelContext
    /// 控制重置確認對話框的顯示。
    @State private var showingResetConfirmation = false

    /// 該批次所有題目的累計錯誤次數總和。
    private var totalWrongCount: Int {
        batch.items.reduce(0) { $0 + $1.wrongCount }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("批次 \(batch.index)").font(.largeTitle.bold())
                Text("\(batch.items.count) 題 · 累計錯 \(totalWrongCount) 次")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("重算錯誤次數") {
                    showingResetConfirmation = true
                }
                .font(.footnote)
                .buttonStyle(.borderless)
                .disabled(totalWrongCount == 0)
            }
            .padding(.top, 32)

            Spacer()

            VStack(spacing: 16) {
                NavigationLink {
                    GrammarPreviewView(batch: batch)
                } label: {
                    Label("先預習所有題目", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    GrammarQuizView(
                        session: GrammarQuizSession(batch: batch),
                        batch: batch,
                        isMistakeQuiz: false
                    )
                } label: {
                    Label("直接開始測驗", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 48)
        }
        .navigationTitle("批次首頁")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "重算這批的錯誤次數？",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重算", role: .destructive) { resetWrongCounts() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這批 \(batch.items.count) 題的累計錯誤次數將歸零，且無法復原。題目內容不受影響。")
        }
    }

    /// 把該批次每一題的 wrongCount 歸零；不動內容欄位與 importOrder。
    private func resetWrongCounts() {
        for item in batch.items {
            item.resetWrongCount()
        }
        try? modelContext.save()
    }
}
