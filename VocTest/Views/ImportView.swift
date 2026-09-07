import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 單字匯入頁：讓使用者選擇目標分組後，以「貼上 Markdown」或「選擇檔案」兩種方式
/// 將單字內容解析並加入指定的 Deck，並顯示匯入結果與被跳過的無效行。
struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// 依建立時間排序的所有分組，供目標分組 Picker 選擇。
    @Query(sort: \Deck.createdAt) private var allDecks: [Deck]

    /// 外部指定的預設目標分組（可為 nil，此時退回第一個分組）。
    let targetDeck: Deck?

    /// 目前選定的分組 ID；為 nil 時由 selectedDeck 推導預設值。
    @State private var selectedDeckID: PersistentIdentifier?
    /// 「貼上 Markdown」文字框的內容。
    @State private var pasteText: String = ""
    @State private var showingFilePicker = false
    /// 解析過程中被跳過的無效行，於下方區塊列出。
    @State private var parseErrors: [ParseError] = []
    /// 最近一次匯入的統計結果（新增卡數與新批次數）。
    @State private var lastResult: ImportResult?

    init(targetDeck: Deck? = nil) {
        self.targetDeck = targetDeck
    }

    private var selectedDeck: Deck? {
        if let id = selectedDeckID {
            return allDecks.first { $0.persistentModelID == id }
        }
        return targetDeck ?? allDecks.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目標分組") {
                    Picker("分組", selection: Binding(
                        get: { selectedDeck?.persistentModelID },
                        set: { selectedDeckID = $0 }
                    )) {
                        ForEach(allDecks) { deck in
                            Text(deck.name).tag(Optional(deck.persistentModelID))
                        }
                    }
                }

                Section("貼上 Markdown") {
                    TextEditor(text: $pasteText)
                        .frame(minHeight: 140)
                        .font(.body.monospaced())
                    Button("匯入貼上內容", action: importPasted)
                        .disabled(pasteText.trimmingCharacters(in: .whitespaces).isEmpty || selectedDeck == nil)
                }

                Section("從檔案匯入") {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("選擇 .md 或 .txt 檔", systemImage: "doc.text")
                    }
                    .disabled(selectedDeck == nil)
                }

                if let result = lastResult {
                    Section("匯入結果") {
                        Text("新增 \(result.cardsAdded) 張卡，產生 \(result.batchesAdded) 個新批次")
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
            .navigationTitle("匯入單字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.text, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFilePickerResult(result)
            }
            .onAppear {
                if selectedDeckID == nil {
                    selectedDeckID = targetDeck?.persistentModelID ?? allDecks.first?.persistentModelID
                }
            }
        }
    }

    private func importPasted() {
        guard let deck = selectedDeck else { return }
        runImport(rawText: pasteText, into: deck)
        pasteText = ""
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard let deck = selectedDeck else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                return
            }
            runImport(rawText: text, into: deck)
        case .failure:
            break
        }
    }

    private func runImport(rawText: String, into deck: Deck) {
        // 解析 Markdown → 記錄無效行 → 比對匯入前後批次數以算出新增的批次數量。
        let parsed = MarkdownParser.parse(rawText)
        parseErrors = parsed.errors
        let beforeBatches = deck.batches.count
        CardImporter.appendCards(parsed.cards, to: deck, in: modelContext)
        try? modelContext.save()
        let afterBatches = deck.batches.count
        lastResult = ImportResult(
            cardsAdded: parsed.cards.count,
            batchesAdded: afterBatches - beforeBatches
        )
    }
}

private struct ImportResult {
    let cardsAdded: Int
    let batchesAdded: Int
}
