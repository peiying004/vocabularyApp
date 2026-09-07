import SwiftData
import SwiftUI

/// 文法批次預習頁：依匯入順序列出該批次的所有題目，可進入測驗；
/// 在編輯模式下支援多選題目並刪除，非編輯模式下選取一列可推入該題的編輯頁。
struct GrammarPreviewView: View {
    let batch: GrammarBatch
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// 編輯模式下被多選的題目 ID 集合。
    @State private var selection = Set<PersistentIdentifier>()
    /// 控制刪除確認對話框的顯示。
    @State private var showingDeleteConfirmation = false
    /// 目前開啟中的新增流程；nil 表示沒有。決定寫入目標是本批次或 deck 末端的新批次。
    @State private var creation: CreationRoute?
    /// 是否顯示「批次已滿」提示視窗。
    @State private var showingFullBatchAlert = false
    /// 滿載後使用者選了「開新批次」，顯示以 deck 為目標的選單。
    @State private var showingNewBatchMenu = false

    /// 「＋」選單選出的路徑，含寫入目標。
    private enum CreationRoute: Identifiable {
        case manual(GrammarItemEditView.Mode)
        case paste(GrammarBatchImportView.Target)

        var id: String {
            switch self {
            case .manual: return "manual"
            case .paste: return "paste"
            }
        }
    }

    private var sortedItems: [GrammarItem] {
        batch.items.sorted { $0.importOrder < $1.importOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                // 以 NavigationLink 推入編輯頁；進入編輯模式時 List 的 selection
                // 會自動接管，因此不需要自行判斷 editMode。
                ForEach(sortedItems) { item in
                    NavigationLink {
                        GrammarItemEditView(mode: .edit(item)) { batchRemoved in
                            // 刪光整批時批次已不存在，這一頁要跟著關掉。
                            if batchRemoved { dismiss() }
                        }
                    } label: {
                        GrammarItemRow(item: item)
                    }
                }
            }
            NavigationLink {
                GrammarQuizView(
                    session: GrammarQuizSession(batch: batch),
                    batch: batch,
                    isMistakeQuiz: false
                )
            } label: {
                Text("開始測驗")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("預習 (批次 \(batch.index))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 刻意不加 .disabled：停用的按鈕按不下去，使用者就無從得知
                // 為什麼不能新增。批次未滿直接開選單；已滿則先說明再讓他決定
                // 要不要續往新批次。
                if GrammarItemEditor.canAppend(to: batch) {
                    creationMenu
                } else {
                    Button {
                        showingFullBatchAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("刪除\(selection.isEmpty ? "" : " (\(selection.count))")")
                }
                .disabled(selection.isEmpty)
            }
        }
        .sheet(item: $creation) { route in
            NavigationStack {
                switch route {
                case .manual(let mode):
                    GrammarItemEditView(mode: mode)
                case .paste(let target):
                    GrammarBatchImportView(target: target)
                }
            }
        }
        .confirmationDialog(
            "本批次已滿",
            isPresented: $showingFullBatchAlert,
            titleVisibility: .visible
        ) {
            // 「開新批次」只是切換寫入目標；批次要等實際儲存內容時才會建立。
            Button("開新批次") { showingNewBatchMenu = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這個批次已有 \(GrammarItemEditor.capacity) 題。要把新內容放進新批次嗎？")
        }
        .confirmationDialog(
            "新增到新批次",
            isPresented: $showingNewBatchMenu,
            titleVisibility: .visible
        ) {
            if let deck = batch.deck {
                Button("手動輸入一筆") { creation = .manual(.createInNewBatch(deck)) }
                Button("貼上 Markdown") { creation = .paste(.deck(deck)) }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "刪除 \(selection.count) 題？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) { deleteSelectedItems() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("選取的題目與其練習紀錄將永久刪除，且無法復原。")
        }
    }

    /// 批次未滿時的「＋」選單，兩個選項都以目前批次為寫入目標。
    /// 滿載時的 deck 目標選單由 `showingNewBatchMenu` 的 confirmationDialog 提供。
    private var creationMenu: some View {
        Menu {
            Button("手動輸入一筆") {
                creation = .manual(.create(batch))
            }
            Button("貼上 Markdown") {
                creation = .paste(.batch(batch))
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private func deleteSelectedItems() {
        // 刪除多選的題目；若整個批次被清空，則連同批次一併刪除、
        // 重新編號其餘批次（reindexBatches）並關閉此頁。
        let allItems = sortedItems
        let itemsToDelete = allItems.filter { selection.contains($0.persistentModelID) }
        guard !itemsToDelete.isEmpty else { return }
        let willEmptyBatch = itemsToDelete.count == allItems.count

        for item in itemsToDelete {
            modelContext.delete(item)
        }
        selection.removeAll()

        if willEmptyBatch {
            let deck = batch.deck
            modelContext.delete(batch)
            deck?.reindexBatches()
            dismiss()
        }
    }
}
