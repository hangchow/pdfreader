import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var library: BookLibrary
    @EnvironmentObject private var progressStore: ProgressStore

    @State private var isFolderPickerPresented = false
    @State private var path: [PDFBook] = []

    private let columns = [
        GridItem(.adaptive(minimum: 142, maximum: 190), spacing: 22, alignment: .top)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch library.state {
                case .needsFolder:
                    folderPrompt
                case .loading:
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready:
                    bookGrid
                case .empty:
                    emptyState
                case .failed(let message):
                    failureState(message)
                }
            }
            .navigationTitle("书库")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            library.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(library.folderURL == nil)

                        Button {
                            isFolderPickerPresented = true
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isFolderPickerPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else {
                    return
                }
                library.chooseFolder(url)
            }
            .navigationDestination(for: PDFBook.self) { book in
                ReaderView(book: book)
            }
        }
        .task {
            library.load()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            library.refresh()
        }
        .onChange(of: library.requestedBook) { book in
            guard let book else { return }
            path.append(book)
            library.clearOpenRequest()
        }
        .alert(
            "无法生成 TXT",
            isPresented: Binding(
                get: { library.generationErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        library.clearGenerationError()
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearGenerationError()
            }
        } message: {
            Text(library.generationErrorMessage ?? "")
        }
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(library.books) { book in
                    Button {
                        library.openBook(book)
                    } label: {
                        BookCardView(
                            book: book,
                            progress: progressStore.progress(for: book),
                            generationProgress: library.generationProgressByBookID[book.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var folderPrompt: some View {
        UnavailableStateView(
            title: "选择 pdfreader 文件夹",
            systemImage: "icloud.and.arrow.down",
            message: "在 iCloud Drive 中选择 pdfreader 目录后，书库会自动显示里面的 PDF。"
        ) {
            Button {
                isFolderPickerPresented = true
            } label: {
                Label("选择文件夹", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        UnavailableStateView(
            title: "没有 PDF",
            systemImage: "books.vertical",
            message: "当前文件夹中还没有可阅读的 PDF 文件。"
        ) {
            Button {
                library.refresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
        }
    }

    private func failureState(_ message: String) -> some View {
        UnavailableStateView(
            title: "无法打开书库",
            systemImage: "exclamationmark.triangle",
            message: message
        ) {
            Button {
                isFolderPickerPresented = true
            } label: {
                Label("重新选择", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct UnavailableStateView<Actions: View>: View {
    let title: String
    let systemImage: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            actions()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
