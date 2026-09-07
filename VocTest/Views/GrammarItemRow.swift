import SwiftUI

/// 文法題列表列：顯示一題 GrammarItem 的題目、正解、干擾選項與（若有）解析。
struct GrammarItemRow: View {
    let item: GrammarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.question)
                .font(.body)
            Text("正解：\(item.correct)")
                .font(.callout)
                .foregroundStyle(.green)
            Text("干擾：\(item.distractors.joined(separator: " / "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let explanation = item.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
