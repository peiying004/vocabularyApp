import SwiftData
import SwiftUI

/// 單字分組列表：單字測驗流程的第二層，列出所有 Deck 並可新增／刪除。
/// 點選分組會導向 BatchListView 查看其批次。
struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    /// 依建立時間排序的所有單字分組，由 SwiftData 自動同步。
    @Query(sort: \Deck.createdAt) private var decks: [Deck]
    /// 控制「新增分組」alert 是否顯示。
    @State private var showingNewDeckPrompt = false
    @State private var newDeckName = ""
    /// 編輯模式下被勾選的分組集合，用於批次刪除。
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingDeleteConfirmation = false

    private var selectedDecks: [Deck] {
        decks.filter { selection.contains($0.persistentModelID) }
    }

    private var selectedBatchCount: Int {
        selectedDecks.reduce(0) { $0 + $1.batches.count }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                ContentUnavailableView {
                    Label("還沒有任何分組", systemImage: "rectangle.stack.badge.plus")
                } description: {
                    Text("建立第一個分組來開始匯入單字。")
                } actions: {
                    Button("建立分組") { showingNewDeckPrompt = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(decks) { deck in
                        NavigationLink {
                            BatchListView(deck: deck)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(deck.name).font(.headline)
                                Text("\(deck.batches.count) 批次").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("分組")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewDeckPrompt = true } label: {
                    Image(systemName: "plus")
                }
            }
            if !decks.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("刪除\(selection.isEmpty ? "" : " (\(selection.count))")")
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .alert("新增分組", isPresented: $showingNewDeckPrompt) {
            TextField("分組名稱（例如 TOEIC 常考）", text: $newDeckName)
            Button("取消", role: .cancel) { newDeckName = "" }
            Button("建立") {
                let trimmed = newDeckName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let deck = Deck(name: trimmed)
                modelContext.insert(deck)
                newDeckName = ""
            }
        }
        .confirmationDialog(
            "刪除 \(selection.count) 個分組？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) { deleteSelectedDecks() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這些分組底下共 \(selectedBatchCount) 個批次與所有單字、練習紀錄將一併永久刪除，且無法復原。")
        }
    }

    // 刪除選取的分組；SwiftData 的關聯會連帶級聯刪除底下的批次與單字。
    private func deleteSelectedDecks() {
        let decksToDelete = selectedDecks
        guard !decksToDelete.isEmpty else { return }
        for deck in decksToDelete {
            modelContext.delete(deck)
        }
        selection.removeAll()
    }
}
