import SwiftUI

/// 單字列表列：以「單字 (詞性) — 翻譯」格式顯示一張 Card，詞性不存在時省略。
struct CardListRow: View {
    let card: Card

    var renderedText: String {
        if let pos = card.partOfSpeech, !pos.isEmpty {
            return "\(card.word) (\(pos)) — \(card.translation)"
        }
        return "\(card.word) — \(card.translation)"
    }

    var body: some View {
        Text(renderedText)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
