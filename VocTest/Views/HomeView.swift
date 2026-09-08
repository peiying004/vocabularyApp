import SwiftUI

/// 首頁：App 導覽的第一層，讓使用者在「單字」與「文法」兩種測驗模式間選擇，
/// 分別導向 DeckListView 與 GrammarDeckListView。
/// toolbar 另有說明按鈕，可隨時重看首次啟動教學。
struct HomeView: View {
    /// 使用者按下說明按鈕時呼叫。教學遮罩由根 view 持有，這裡只負責發出請求。
    let onShowTutorial: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            NavigationLink {
                DeckListView()
            } label: {
                HomeButtonLabel(
                    systemImage: "character.book.closed.fill",
                    title: "單字",
                    subtitle: "四選一翻譯測驗",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GrammarDeckListView()
            } label: {
                HomeButtonLabel(
                    systemImage: "text.book.closed.fill",
                    title: "文法",
                    subtitle: "填空四選一",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .navigationTitle("VocTest")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onShowTutorial) {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("查看使用教學")
            }
        }
    }
}

/// 首頁按鈕外觀：圖示、標題、副標與右側箭頭組成的卡片樣式 label。
private struct HomeButtonLabel: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
