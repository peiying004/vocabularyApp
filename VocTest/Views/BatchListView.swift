import SwiftData
import SwiftUI

/// 批次列表：顯示某個 Deck 底下依 index 排序的所有批次（每 `CardImporter.chunkSize` 張切一批）。
/// 可從此匯入單字，或點選批次進入 BatchHomeView 開始複習／測驗。
struct BatchListView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext
    /// 控制匯入單字的 sheet 是否顯示。
    @State private var showingImporter = false
    /// 編輯模式下被勾選的批次集合，用於批次刪除。
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingDeleteConfirmation = false

    private var sortedBatches: [Batch] {
        deck.batches.sorted { $0.index < $1.index }
    }

    private var selectedBatches: [Batch] {
        sortedBatches.filter { selection.contains($0.persistentModelID) }
    }

    private var selectedCardCount: Int {
        selectedBatches.reduce(0) { $0 + $1.cards.count }
    }

    var body: some View {
        Group {
            if sortedBatches.isEmpty {
                ContentUnavailableView {
                    Label("這個分組還沒有單字", systemImage: "doc.text.below.ecg")
                } description: {
                    Text("匯入單字後會自動每 \(CardImporter.chunkSize) 張切成一批。")
                } actions: {
                    Button("匯入單字") { showingImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(sortedBatches) { batch in
                        NavigationLink {
                            BatchHomeView(batch: batch)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("批次 \(batch.index)").font(.headline)
                                    Text("\(batch.cards.count) 張卡").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("累計錯 \(batch.cards.reduce(0) { $0 + $1.wrongCount }) 次")
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
        // 匯入的單字會加入此 deck，並自動切成多個批次。
        .sheet(isPresented: $showingImporter) {
            ImportView(targetDeck: deck)
        }
        .confirmationDialog(
            "刪除 \(selection.count) 個批次？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) { deleteSelectedBatches() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這些批次共 \(selectedCardCount) 張卡與其練習紀錄將一併永久刪除，且無法復原。")
        }
    }

    // 刪除選取的批次（連帶級聯刪除其單字），再重新編號剩餘批次讓 index 連續。
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
