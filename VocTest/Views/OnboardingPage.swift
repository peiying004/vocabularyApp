import SwiftUI

/// 首次啟動教學的單一頁面內容。
///
/// 四頁內容是靜態常數，不由使用者資料推導 —— 教學要在資料庫全空的首次啟動時就能顯示。
struct OnboardingPage: Identifiable {
    /// 示意圖種類。實際繪製在 `OnboardingIllustrations.swift`，
    /// 這裡只留識別方式，讓內容定義與繪製邏輯分離。
    enum Illustration: Equatable {
        /// 兩張並列的路線卡片。
        case twoRoutes
        /// Markdown 表格轉成一疊批次卡片。
        case pasteToBatches
        /// 一題四個選項，其中一個標為正解。
        case fourChoices
        /// 錯題繞回佇列尾端的循環箭頭。
        case wrongAnswerLoop
    }

    let id: Int
    let illustration: Illustration
    let title: String
    let body: String
}

extension OnboardingPage {
    /// 教學的四頁內容，順序即翻頁順序。
    ///
    /// 第 2 頁的批次大小直接引用 `CardImporter.chunkSize`（文法側的
    /// `GrammarItemImporter.chunkSize` 刻意同值），容量調整時文案自動跟著更新。
    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            illustration: .twoRoutes,
            title: "兩條學習路線",
            body: """
            單字是看英文，從四個選項裡選出正確的中文翻譯。
            文法是填空題，從四個選項裡選出正確的答案。
            兩條路線各自獨立，題庫不會互相混到。
            從首頁的兩顆按鈕進去就對了。
            """
        ),
        OnboardingPage(
            id: 1,
            illustration: .pasteToBatches,
            title: "貼上就能出題",
            body: """
            把單字表或文法題以 Markdown 表格貼上，App 會自動解析。
            也可以直接選擇 .md 或 .txt 檔匯入。
            內容會依每 \(CardImporter.chunkSize) 題一批自動切好，不用自己分頁。
            解析不了的行會列出行號，方便你回去修。
            """
        ),
        OnboardingPage(
            id: 2,
            illustration: .fourChoices,
            title: "四選一測驗",
            body: """
            每一題都會配上三個干擾選項，湊成四選一。
            干擾選項從同一批裡隨機抽，不足時才擴及同分組的其他批。
            所以你不會在「錯的那幾張」之間亂猜。
            答錯會立刻顯示正確答案。
            """
        ),
        OnboardingPage(
            id: 3,
            illustration: .wrongAnswerLoop,
            title: "答錯會再問一次",
            body: """
            答錯的題目會被重新插回佇列後方。
            隔幾題之後再問你一次，直到本輪全部答對才結束。
            結束後會統計答對數與累計錯誤次數，並列出錯題。
            你也可以只針對這輪的錯題再測一輪。
            """
        )
    ]
}
