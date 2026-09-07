import SwiftData
import SwiftUI

/// 單字編輯頁：支援「修改既有卡片」與「新增一張卡」，新增可指定寫入既有批次或 deck 末端的新批次。
/// 修改既有卡片由預習頁的 `NavigationLink` 推入；新增由工具列「＋」以 sheet 呈現，
/// 因此本身不包 `NavigationStack`——sheet 呼叫端負責包。
/// 輸入先進本地暫存狀態，按下「儲存」才經 `CardEditor` 寫回模型，
/// 因此離開畫面而未儲存不會在資料中留下任何痕跡。
struct CardEditView: View {
    /// 這個畫面的三種用途。
    enum Mode {
        /// 修改既有卡片。
        case edit(Card)
        /// 在指定批次末端新增一張卡。
        case create(Batch)
        /// 在 deck 末端新建立的批次裡新增一張卡。批次在儲存時才建立，不會留下空批次。
        case createInNewBatch(Deck)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var word: String
    @State private var partOfSpeech: String
    @State private var translation: String
    /// 控制刪除確認對話框的顯示。
    @State private var showingDeleteConfirmation = false

    /// 刪除既有卡片後回呼，參數表示所屬批次是否也被移除，
    /// 供預習頁決定要不要一併關閉自己。
    var onDelete: ((Bool) -> Void)?

    init(mode: Mode, onDelete: ((Bool) -> Void)? = nil) {
        self.mode = mode
        self.onDelete = onDelete
        switch mode {
        case .edit(let card):
            _word = State(initialValue: card.word)
            _partOfSpeech = State(initialValue: card.partOfSpeech ?? "")
            _translation = State(initialValue: card.translation)
        case .create, .createInNewBatch:
            _word = State(initialValue: "")
            _partOfSpeech = State(initialValue: "")
            _translation = State(initialValue: "")
        }
    }

    private var editingCard: Card? {
        if case .edit(let card) = mode { return card }
        return nil
    }

    private var canSave: Bool {
        CardEditor.isValid(word: word, translation: translation)
    }

    var body: some View {
        Form {
            Section("單字") {
                TextField("word", text: $word)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("詞性（可留空）") {
                TextField("n. / v. / adj.", text: $partOfSpeech)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("翻譯") {
                TextField("中文翻譯", text: $translation)
            }

            if editingCard != nil {
                Section {
                    Button("刪除這張卡", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(editingCard == nil ? "新增單字" : "編輯單字")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 新增是 sheet，需要明確的「取消」；編輯是推入的頁面，返回鍵即取消。
            if editingCard == nil {
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
            "刪除這張卡？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive, action: delete)
            Button("取消", role: .cancel) {}
        } message: {
            Text("這張卡與其練習紀錄將永久刪除，且無法復原。")
        }
    }

    private func save() {
        switch mode {
        case .edit(let card):
            // 只寫入內容欄位；wrongCount 與 importOrder 不受影響。
            guard CardEditor.update(
                card,
                word: word,
                partOfSpeech: partOfSpeech,
                translation: translation
            ) else { return }
        case .create(let batch):
            guard CardEditor.appendCard(
                to: batch,
                word: word,
                partOfSpeech: partOfSpeech,
                translation: translation,
                in: modelContext
            ) != nil else { return }
        case .createInNewBatch(let deck):
            // 走與貼上相同的路徑：批次由 CardImporter 在寫入內容時建立，
            // 因此不存在「先建空批次再填」的中間狀態。
            let parsed = ParsedCard(
                word: word,
                partOfSpeech: partOfSpeech,
                translation: translation
            )
            let result = CardEditor.appendCardsInNewBatches([parsed], to: deck, in: modelContext)
            guard result.totalAdded > 0 else { return }
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let card = editingCard else { return }
        let batchRemoved = CardEditor.deleteCard(card, in: modelContext)
        try? modelContext.save()
        dismiss()
        onDelete?(batchRemoved)
    }
}
