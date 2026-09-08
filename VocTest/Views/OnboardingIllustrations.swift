import SwiftUI

/// 教學頁的示意圖。全部以 SwiftUI 原生形狀與文字疊出，不使用任何圖片資產，
/// 顏色一律取語意色彩或 `.tint` 系統色，深淺色模式自動跟隨。
struct OnboardingIllustration: View {
    let kind: OnboardingPage.Illustration

    var body: some View {
        Group {
            switch kind {
            case .twoRoutes: TwoRoutesArt()
            case .pasteToBatches: PasteToBatchesArt()
            case .fourChoices: FourChoicesArt()
            case .wrongAnswerLoop: WrongAnswerLoopArt()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108)
    }
}

// MARK: - 共用零件

/// 示意圖裡的小方塊，統一圓角與底色。
private struct Chip<Content: View>: View {
    var tint: Color = .secondary
    var filled: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Color.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(filled ? tint : tint.opacity(0.15))
            )
    }
}

// MARK: - 第 1 頁：兩張並列的路線卡片

private struct TwoRoutesArt: View {
    var body: some View {
        HStack(spacing: 12) {
            routeCard(systemImage: "character.book.closed.fill", title: "單字", line: "apple → 蘋果", tint: .blue)
            routeCard(systemImage: "text.book.closed.fill", title: "文法", line: "He ___ it.", tint: .orange)
        }
        .padding(.horizontal, 8)
    }

    private func routeCard(systemImage: String, title: String, line: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Text(line)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

// MARK: - 第 2 頁：Markdown 表格轉成一疊批次卡片

private struct PasteToBatchesArt: View {
    var body: some View {
        HStack(spacing: 10) {
            markdownTable
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
            batchStack
        }
        .padding(.horizontal, 8)
    }

    private var markdownTable: some View {
        VStack(spacing: 3) {
            tableRow(left: "單字", right: "翻譯", header: true)
            tableRow(left: "apple", right: "蘋果", header: false)
            tableRow(left: "book", right: "書", header: false)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    private func tableRow(left: String, right: String, header: Bool) -> some View {
        HStack(spacing: 4) {
            Text(left)
            Divider().frame(height: 9)
            Text(right)
        }
        .font(.system(size: 9, weight: header ? .bold : .regular))
        .foregroundStyle(header ? Color.primary : Color.secondary)
        .frame(width: 74, alignment: .leading)
    }

    private var batchStack: some View {
        ZStack {
            ForEach(0..<3) { depth in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 62, height: 40)
                    .offset(x: CGFloat(2 - depth) * 5, y: CGFloat(2 - depth) * -5)
            }
            Text("第 1 批")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.blue)
                .offset(x: 10, y: -10)
        }
        .frame(width: 78)
    }
}

// MARK: - 第 3 頁：四選一，其中一個標為正解

private struct FourChoicesArt: View {
    private let options = ["蘋果", "書本", "桌子", "椅子"]

    var body: some View {
        VStack(spacing: 6) {
            Text("apple")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Chip(tint: index == 0 ? .green : .secondary, filled: index == 0) {
                        HStack(spacing: 2) {
                            if index == 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            Text(option).lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - 第 4 頁：錯題繞回佇列尾端

private struct WrongAnswerLoopArt: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Chip(tint: .red, filled: true) {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                        Text("錯題")
                    }
                }
                queueSlot("下一題")
                queueSlot("再下題")
                queueSlot("…")
                Chip(tint: .red) { Text("錯題") }
            }

            HStack(spacing: 0) {
                Image(systemName: "arrow.turn.left.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .rotationEffect(.degrees(180))
                Rectangle()
                    .fill(Color.red.opacity(0.45))
                    .frame(height: 1.5)
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
            }
            .frame(height: 14)

            Text("全部答對才結束")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
    }

    private func queueSlot(_ text: String) -> some View {
        Chip { Text(text).lineLimit(1).minimumScaleFactor(0.6) }
    }
}

#Preview("四張示意圖") {
    VStack(spacing: 16) {
        OnboardingIllustration(kind: .twoRoutes)
        OnboardingIllustration(kind: .pasteToBatches)
        OnboardingIllustration(kind: .fourChoices)
        OnboardingIllustration(kind: .wrongAnswerLoop)
    }
    .padding()
}
