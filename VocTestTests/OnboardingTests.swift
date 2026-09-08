import XCTest
@testable import VocTest

/// Task 4.1：鎖住首次啟動教學的四頁內容定義，避免日後被誤改。
///
/// 刻意不碰 `UserDefaults.standard` —— 旗標行為以手動驗收涵蓋，
/// 這裡只驗證靜態內容，才不會污染其他測試的環境。
final class OnboardingTests: XCTestCase {

    /// 依 specs/onboarding「Tutorial Page Content And Paging」規定的四頁標題與順序。
    private let expectedTitles = ["兩條學習路線", "貼上就能出題", "四選一測驗", "答錯會再問一次"]

    func test_PageCountIsExactlyFour() {
        XCTAssertEqual(OnboardingPage.all.count, 4)
    }

    func test_TitlesMatchSpecOrder() {
        XCTAssertEqual(OnboardingPage.all.map(\.title), expectedTitles)
    }

    func test_EveryPageHasNonEmptyTitleAndBody() {
        for page in OnboardingPage.all {
            XCTAssertFalse(page.title.isEmpty, "第 \(page.id + 1) 頁標題不可為空")
            XCTAssertFalse(page.body.isEmpty, "第 \(page.id + 1) 頁說明文字不可為空")
        }
    }

    /// id 同時是 TabView 的 tag 與翻頁順序，必須是從 0 起算的連續整數。
    func test_PageIdsAreContiguousFromZero() {
        XCTAssertEqual(OnboardingPage.all.map(\.id), Array(0..<OnboardingPage.all.count))
    }

    /// 每頁配一張不同的示意圖，四頁不得重複。
    func test_EachPageHasDistinctIllustration() {
        let kinds = OnboardingPage.all.map(\.illustration)
        for (index, kind) in kinds.enumerated() {
            XCTAssertFalse(kinds[(index + 1)...].contains(kind), "第 \(index + 1) 頁的示意圖與後面某頁重複")
        }
    }

    /// 第 2 頁的批次大小必須由 `CardImporter.chunkSize` 推導，容量調整時文案要自動跟著改。
    func test_PasteToBatchesPageQuotesTheActualChunkSize() {
        let page = OnboardingPage.all[1]
        XCTAssertTrue(
            page.body.contains("\(CardImporter.chunkSize)"),
            "第 2 頁說明文字應引用實際的批次大小 \(CardImporter.chunkSize)"
        )
    }
}
