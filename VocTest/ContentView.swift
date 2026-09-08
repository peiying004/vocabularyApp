import SwiftUI

/// App 的根 view：提供全域的 NavigationStack，並以 HomeView 作為導覽起點。
///
/// 首次啟動教學以 `.overlay` 疊在 NavigationStack 之上，而非掛在 HomeView 內部 ——
/// 遮罩的生命週期因此與導覽狀態無關。
struct ContentView: View {
    /// 教學是怎麼被打開的。決定關閉時要不要寫入「已看過」旗標。
    private enum OnboardingSource {
        /// 首次啟動自動顯示：關閉時把旗標設為已看過。
        case firstLaunch
        /// 使用者從首頁說明按鈕手動開啟：關閉時不動旗標。
        case replay
    }

    /// 是否已看過首次啟動教學。鍵不存在時為 `false`，等同首次啟動。
    ///
    /// 刻意不用「資料庫是否為空」判斷：使用者把內容全部刪光是常態操作，
    /// 那時不該把教學再彈一次。
    @AppStorage(OnboardingOverlayView.hasSeenKey) private var hasSeenOnboarding = false

    /// 目前正在顯示的教學來源；`nil` 表示沒有顯示教學。
    @State private var onboardingSource: OnboardingSource?

    var body: some View {
        NavigationStack {
            HomeView(onShowTutorial: { onboardingSource = .replay })
        }
        .overlay {
            if let source = onboardingSource {
                OnboardingOverlayView {
                    if source == .firstLaunch {
                        hasSeenOnboarding = true
                    }
                    onboardingSource = nil
                }
            }
        }
        .onAppear {
            if !hasSeenOnboarding, onboardingSource == nil {
                onboardingSource = .firstLaunch
            }
        }
    }
}
