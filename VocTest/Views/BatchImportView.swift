import SwiftData
import SwiftUI

/// 批次層級的單字貼上頁：把 Markdown 解析後寫入**指定的目標**，
/// 與 deck 層級的 `ImportView` 不同——後者一定另建新批次。
///
/// 兩種目標：
/// - `.batch`：寫進該既有批次，超過剩餘容量時由使用者選擇開新批次或放棄。
/// - `.deck`：所有內容一律進 deck 末端的新批次，不需要容量計算也不會超量。
struct BatchImportView: View {
    /// 這次貼上要寫到哪裡。
    enum Target {
        /// 寫進這個既有批次。
        case batch(Batch)
        /// 寫進這個 deck 末端新建立的批次。
        case deck(Deck)
    }

    let target: Target
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pasteText: String = ""
    /// 解析過程中被跳過的無效行。與「超量」是兩件事，分開呈現。
    @State private var parseErrors: [ParseError] = []
    /// 最近一次寫入的統計結果。
    @State private var lastResult: CardEditor.BulkAppendResult?
    /// 超量確認視窗的待決內容；非 nil 時顯示視窗。
    @State private var pendingOverflow: PendingOverflow?

    /// 超量時暫存的解析結果，等使用者決定後才寫入。
    private struct PendingOverflow: Identifiable {
        let id = UUID()
        let parsed: [ParsedCard]
        let room: Int
        var overflowCount: Int { parsed.count - room }
    }

    private var targetBatch: Batch? {
        if case .batch(let batch) = target { return batch }
        return nil
    }

    /// 目標批次還能放幾張；deck 目標沒有這個概念。
    private var remainingCapacity: Int? {
        targetBatch.map { CardEditor.remainingCapacity(of: $0) }
    }

    private var canImport: Bool {
        !pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("貼上 Markdown") {
                    if let remainingCapacity {
                        Text("這個批次還能放 \(remainingCapacity) 張卡。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("內容會放進新的批次。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $pasteText)
                        .frame(minHeight: 140)
                        .font(.body.monospaced())
                    Button("匯入貼上內容", action: runImport)
                        .disabled(!canImport)
                }

                if let result = lastResult {
                    Section("匯入結果") {
                        Text(resultDescription(result))
                            .font(.subheadline)
                    }
                }

                if !parseErrors.isEmpty {
                    Section("無效行（已跳過）") {
                        ForEach(Array(parseErrors.enumerated()), id: \.offset) { _, err in
                            VStack(alignment: .leading) {
                                Text("第 \(err.lineNumber) 行").font(.caption).foregroundStyle(.red)
                                Text(err.rawLine).font(.caption.monospaced())
                            }
                        }
                    }
                }
            }
            .navigationTitle("貼上單字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .confirmationDialog(
                "這個批次放不下全部內容",
                isPresented: Binding(
                    get: { pendingOverflow != nil },
                    set: { if !$0 { pendingOverflow = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingOverflow
            ) { pending in
                Button("開新批次") { commitOverflow(pending) }
                Button("放棄此次新增", role: .cancel) { pendingOverflow = nil }
            } message: { pending in
                Text("本批次只能再放 \(pending.room) 張，還有 \(pending.overflowCount) 張放不下。要把放不下的部分放進新批次嗎？")
            }
        }
    }

    private func resultDescription(_ result: CardEditor.BulkAppendResult) -> String {
        if result.newBatchesCreated > 0 {
            return "新增 \(result.totalAdded) 張卡，其中 \(result.addedToBatch) 張放進本批次，另產生 \(result.newBatchesCreated) 個新批次"
        }
        return "新增 \(result.totalAdded) 張卡"
    }

    private func runImport() {
        let parsed = MarkdownParser.parse(pasteText)
        parseErrors = parsed.errors

        switch target {
        case .deck(let deck):
            // deck 目標沒有剩餘容量的概念，全部進新批次，不會有超量確認。
            let result = CardEditor.appendCardsInNewBatches(parsed.cards, to: deck, in: modelContext)
            finish(with: result)

        case .batch(let batch):
            let room = CardEditor.remainingCapacity(of: batch)
            guard parsed.cards.count > room else {
                let result = CardEditor.appendCards(
                    parsed.cards, to: batch, allowingOverflow: false, in: modelContext
                )
                if let result { finish(with: result) }
                return
            }
            // 超量：先不寫入任何東西，等使用者決定。
            pendingOverflow = PendingOverflow(parsed: parsed.cards, room: room)
        }
    }

    private func commitOverflow(_ pending: PendingOverflow) {
        guard let batch = targetBatch else { return }
        pendingOverflow = nil
        let result = CardEditor.appendCards(
            pending.parsed, to: batch, allowingOverflow: true, in: modelContext
        )
        if let result { finish(with: result) }
    }

    private func finish(with result: CardEditor.BulkAppendResult) {
        try? modelContext.save()
        lastResult = result
        pasteText = ""
    }
}
