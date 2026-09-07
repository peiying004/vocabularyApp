import SwiftData
import SwiftUI

/// 文法題編輯頁：與 `CardEditView` 對稱，支援「修改既有題目」與「新增一題」，
/// 新增可指定寫入既有批次或 deck 末端的新批次。
/// 修改既有題目由預習頁的 `NavigationLink` 推入；新增由工具列「＋」以 sheet 呈現，
/// 因此本身不包 `NavigationStack`——sheet 呼叫端負責包。
/// 干擾選項固定 3 個，畫面上不提供增減欄位的控制項。
struct GrammarItemEditView: View {
    /// 這個畫面的三種用途。
    enum Mode {
        /// 修改既有題目。
        case edit(GrammarItem)
        /// 在指定批次末端新增一題。
        case create(GrammarBatch)
        /// 在 deck 末端新建立的批次裡新增一題。批次在儲存時才建立，不會留下空批次。
        case createInNewBatch(GrammarDeck)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var question: String
    @State private var correct: String
    /// 固定 3 格的干擾選項暫存值，長度恆等於 `GrammarItemEditor.distractorCount`。
    @State private var distractors: [String]
    @State private var explanation: String
    /// 控制刪除確認對話框的顯示。
    @State private var showingDeleteConfirmation = false

    /// 刪除既有題目後回呼，參數表示所屬批次是否也被移除，
    /// 供預習頁決定要不要一併關閉自己。
    var onDelete: ((Bool) -> Void)?

    init(mode: Mode, onDelete: ((Bool) -> Void)? = nil) {
        self.mode = mode
        self.onDelete = onDelete
        let slotCount = GrammarItemEditor.distractorCount
        switch mode {
        case .edit(let item):
            _question = State(initialValue: item.question)
            _correct = State(initialValue: item.correct)
            // 既有資料一律是 3 個，這裡仍補齊／截斷以確保欄位數固定。
            var slots = item.distractors
            slots += Array(repeating: "", count: max(0, slotCount - slots.count))
            _distractors = State(initialValue: Array(slots.prefix(slotCount)))
            _explanation = State(initialValue: item.explanation ?? "")
        case .create, .createInNewBatch:
            _question = State(initialValue: "")
            _correct = State(initialValue: "")
            _distractors = State(initialValue: Array(repeating: "", count: slotCount))
            _explanation = State(initialValue: "")
        }
    }

    private var editingItem: GrammarItem? {
        if case .edit(let item) = mode { return item }
        return nil
    }

    private var canSave: Bool {
        GrammarItemEditor.isValid(
            question: question,
            correct: correct,
            distractors: distractors
        )
    }

    var body: some View {
        Form {
            Section("題目") {
                TextField("題目敘述（含填空）", text: $question, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section("正解") {
                TextField("正確答案", text: $correct)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("干擾選項（固定 \(GrammarItemEditor.distractorCount) 個）") {
                ForEach(distractors.indices, id: \.self) { index in
                    TextField("干擾選項 \(index + 1)", text: $distractors[index])
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            Section("詳解（可留空）") {
                TextField("解析", text: $explanation, axis: .vertical)
                    .lineLimit(2...5)
            }

            if editingItem != nil {
                Section {
                    Button("刪除這一題", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(editingItem == nil ? "新增文法題" : "編輯文法題")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 新增是 sheet，需要明確的「取消」；編輯是推入的頁面，返回鍵即取消。
            if editingItem == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "刪除這一題？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive, action: delete)
            Button("取消", role: .cancel) {}
        } message: {
            Text("這一題與其練習紀錄將永久刪除，且無法復原。")
        }
    }

    private func save() {
        switch mode {
        case .edit(let item):
            // 只寫入內容欄位；wrongCount 與 importOrder 不受影響。
            guard GrammarItemEditor.update(
                item,
                question: question,
                correct: correct,
                distractors: distractors,
                explanation: explanation
            ) else { return }
        case .create(let batch):
            guard GrammarItemEditor.appendItem(
                to: batch,
                question: question,
                correct: correct,
                distractors: distractors,
                explanation: explanation,
                in: modelContext
            ) != nil else { return }
        case .createInNewBatch(let deck):
            // 走與貼上相同的路徑：批次由 GrammarItemImporter 在寫入內容時建立，
            // 因此不存在「先建空批次再填」的中間狀態。
            let parsed = ParsedGrammarItem(
                question: question,
                correct: correct,
                distractors: distractors,
                explanation: explanation
            )
            let result = GrammarItemEditor.appendItemsInNewBatches(
                [parsed], to: deck, in: modelContext
            )
            guard result.totalAdded > 0 else { return }
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let item = editingItem else { return }
        let batchRemoved = GrammarItemEditor.deleteItem(item, in: modelContext)
        try? modelContext.save()
        dismiss()
        onDelete?(batchRemoved)
    }
}
