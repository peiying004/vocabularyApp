import SwiftData
import SwiftUI

/// 文法批次列表：顯示某個 GrammarDeck 底下依 index 排序的所有批次（每 `GrammarItemImporter.chunkSize` 題切一批）。
/// 可從此匯入題目，或點選批次進入 GrammarBatchHomeView 開始預習／測驗。
struct GrammarBatchListView: View {
    let deck: GrammarDeck
    @Environment(\.modelContext) private var modelContext
    /// 控制匯入題目的 sheet 是否顯示。
    @State private var showingImporter = false
    /// 編輯模式下被勾選的批次集合，用於批次刪除。
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingDeleteConfirmation = false

    private var sortedBatches: [GrammarBatch] {
        deck.grammarBatches.sorted { $0.index < $1.index }
    }

    private var selectedBatches: [GrammarBatch] {
        sortedBatches.filter { selection.contains($0.persistentModelID) }
    }

    private var selectedItemCount: Int {
        selectedBatches.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        Group {
            if sortedBatches.isEmpty {
                ContentUnavailableView {
                    Label("這個分組還沒有題目", systemImage: "doc.text.below.ecg")
                } description: {
                    Text("匯入題目後會自動每 \(GrammarItemImporter.chunkSize) 題切成一批。")
                } actions: {
                    Button("匯入題目") { showingImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(sortedBatches) { batch in
                        NavigationLink {
                            GrammarBatchHomeView(batch: batch)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("批次 \(batch.index)").font(.headline)
                                    Text("\(batch.items.count) 題")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("累計錯 \(batch.items.reduce(0) { $0 + $1.wrongCount }) 次")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingImporter = true } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            if !sortedBatches.isEmpty {
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
        // 匯入的題目會加入此 deck，並自動切成多個批次。
        .sheet(isPresented: $showingImporter) {
            GrammarImportView(targetDeck: deck)
        }
        .confirmationDialog(
            "刪除 \(selection.count) 個批次？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) { deleteSelectedBatches() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這些批次共 \(selectedItemCount) 題與其練習紀錄將一併永久刪除，且無法復原。")
        }
    }

    // 刪除選取的批次（連帶級聯刪除其題目），再重新編號剩餘批次讓 index 連續。
    private func deleteSelectedBatches() {
        let batchesToDelete = selectedBatches
        guard !batchesToDelete.isEmpty else { return }
        for batch in batchesToDelete {
            modelContext.delete(batch)
        }
        deck.reindexBatches()
        selection.removeAll()
    }
}
