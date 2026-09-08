import SwiftUI

/// 首次啟動教學的遮罩。刻意做成疊在 `NavigationStack` 之上的 overlay 而非 sheet／
/// fullScreenCover：首頁要隱約可見（保留「我在哪」的脈絡），且日後若要改成
/// coach mark，定位邏輯可以直接長在同一層上。
struct OnboardingOverlayView: View {
    /// 「已看過教學」旗標在 UserDefaults 中的鍵名。
    static let hasSeenKey = "hasSeenOnboarding"

    /// 教學結束時呼叫。呼叫端決定是否要寫入「已看過」旗標。
    let onFinish: () -> Void

    /// 目前顯示的頁次，對應 `OnboardingPage.id`。一律從第 1 頁（id 0）開始。
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            scrim
            card
        }
    }

    /// 半透明遮罩：底下首頁隱約可見，但吸收所有觸控，讓首頁在教學期間不可操作。
    private var scrim: some View {
        Color.black.opacity(0.45)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { /* 刻意留空：點遮罩不關閉，避免誤觸跳過教學 */ }
    }

    /// 教學卡片。位於遮罩之上，因此卡片內的按鈕點得到。
    private var card: some View {
        VStack(spacing: 12) {
            TabView(selection: $currentPage) {
                ForEach(OnboardingPage.all) { page in
                    OnboardingCardContent(page: page)
                        .padding(.horizontal, 4)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 300)

            pageIndicator

            primaryButton
        }
        .padding(20)
        .overlay(alignment: .topTrailing) { closeButton }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .padding(.horizontal, 28)
    }

    /// 目前是否停在最後一頁。
    private var isLastPage: Bool { currentPage == OnboardingPage.all.count - 1 }

    /// 卡片底部的主按鈕。四頁都在同一個位置、同樣高度 —— 卡片翻頁時才不會忽高忽低。
    /// 前三頁前進一頁，最後一頁結束教學；同時也讓還沒意識到卡片可以滑動的人有路可走。
    private var primaryButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation { currentPage += 1 }
            }
        } label: {
            Text(isLastPage ? "開始使用" : "下一步")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    /// 關閉按鈕。疊在卡片內容之上（而非遮罩之下），確保任何一頁都點得到，
    /// 不會出現「教學關不掉、首頁又點不到」的死鎖。
    private var closeButton: some View {
        Button(action: onFinish) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.secondaryLabel), Color(.tertiarySystemFill))
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel("關閉教學")
    }

    /// 頁面指示器。`.page` 樣式內建的指示器在淺色背景上對比不足，
    /// 這裡自繪以確保深淺色模式都看得清楚。
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.all) { page in
                Circle()
                    .fill(page.id == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("第 \(currentPage + 1) 頁，共 \(OnboardingPage.all.count) 頁")
    }
}

/// 單一教學頁的版面：示意圖、標題、說明文字三段。
struct OnboardingCardContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 14) {
            OnboardingIllustration(kind: page.illustration)

            Text(page.title)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(page.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("教學遮罩疊在首頁上") {
    NavigationStack {
        HomeView(onShowTutorial: {})
    }
    .overlay {
        OnboardingOverlayView(onFinish: {})
    }
}
