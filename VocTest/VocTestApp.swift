import SwiftData
import SwiftUI

/// App 進入點：建立主視窗並掛載 ContentView。
/// 透過 `.modelContainer` 註冊所有 SwiftData model（單字與文法兩大類），
/// 讓整個 view 樹都能取用共享的 modelContext。
@main
struct VocTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Deck.self, Batch.self, Card.self, GrammarDeck.self, GrammarBatch.self, GrammarItem.self])
    }
}
