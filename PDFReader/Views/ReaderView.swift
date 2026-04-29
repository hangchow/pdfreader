import SwiftUI

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var preferencesStore: ReaderPreferencesStore

    let book: PDFBook

    @State private var pageRanges: [TextPageRange] = []
    @State private var currentPageIndex = 0
    @State private var showsChrome = false
    @State private var showsMenu = false
    @State private var loadingFailed = false
    @State private var didStartSecurityScope = false
    @State private var loadTask: Task<Void, Never>?
    @State private var scrubbedPageIndex: Int?
    @State private var scrubCommitTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            readerContent
                .ignoresSafeArea()

            if showsChrome {
                chrome
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showsChrome, pageRanges.isEmpty == false {
                bottomProgress
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(!showsChrome)
        .onAppear(perform: openTextBook)
        .onDisappear(perform: closeTextBook)
        .onChange(of: currentPageIndex) { newValue in
            persist(pageIndex: newValue)
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        if pageRanges.isEmpty == false {
            TextPageReaderView(
                textURL: book.textURL,
                pageRanges: pageRanges,
                currentPageIndex: $currentPageIndex,
                preferences: preferencesStore.preferences
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    toggleReaderChrome()
                }
            )
        } else if loadingFailed {
            UnavailableStateView(
                title: "无法打开 TXT",
                systemImage: "doc.badge.gearshape",
                message: "同目录的 TXT 文件暂时无法读取。"
            ) {
                EmptyView()
            }
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if pageRanges.isEmpty == false {
                        Text("第 \(visiblePageIndex + 1)/\(pageRanges.count) 页")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        showsMenu.toggle()
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 34, height: 34)
                }

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        showsChrome = false
                        showsMenu = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)

            if showsMenu {
                ReaderQuickMenu(preferences: $preferencesStore.preferences)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.regularMaterial)
    }

    private var bottomProgress: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                HStack {
                    Text("第 \(visiblePageIndex + 1) 页")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(visiblePageIndex + 1)/\(pageRanges.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if pageRanges.count > 1 {
                    Slider(value: scrubBinding, in: 1...Double(pageRanges.count), step: 1)
                        .tint(.orange)
                } else {
                    ProgressView(value: 1)
                        .tint(.orange)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visiblePageIndex: Int {
        clampedPageIndex(scrubbedPageIndex ?? currentPageIndex)
    }

    private var scrubBinding: Binding<Double> {
        Binding(
            get: {
                Double(visiblePageIndex + 1)
            },
            set: { newValue in
                scheduleScrub(to: Int(newValue.rounded()) - 1)
            }
        )
    }

    private func toggleReaderChrome() {
        withAnimation(.snappy(duration: 0.18)) {
            showsChrome.toggle()
            if showsChrome == false {
                showsMenu = false
            }
        }
    }

    private func scheduleScrub(to pageIndex: Int) {
        let clampedIndex = clampedPageIndex(pageIndex)
        scrubbedPageIndex = clampedIndex
        scrubCommitTask?.cancel()

        scrubCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            currentPageIndex = clampedIndex
            scrubbedPageIndex = nil
            scrubCommitTask = nil
        }
    }

    private func clampedPageIndex(_ pageIndex: Int) -> Int {
        guard pageRanges.isEmpty == false else { return 0 }
        return min(max(pageIndex, 0), pageRanges.count - 1)
    }

    private func openTextBook() {
        guard loadTask == nil else { return }

        if didStartSecurityScope == false {
            didStartSecurityScope = book.textURL.startAccessingSecurityScopedResource()
        }

        let textURL = book.textURL
        let savedIndex = progressStore.pageIndex(for: book)

        loadTask = Task {
            do {
                let loadedPageRanges = try await TextPageFile.buildPageRanges(from: textURL)
                guard !Task.isCancelled else { return }

                pageRanges = loadedPageRanges.isEmpty ? [TextPageRange(startOffset: 0, endOffset: 0)] : loadedPageRanges
                loadingFailed = false

                currentPageIndex = min(max(savedIndex, 0), max(pageRanges.count - 1, 0))
                persist(pageIndex: currentPageIndex)
            } catch {
                guard !Task.isCancelled else { return }
                loadingFailed = true
            }
        }
    }

    private func closeTextBook() {
        loadTask?.cancel()
        loadTask = nil
        scrubCommitTask?.cancel()
        scrubCommitTask = nil
        persist(pageIndex: currentPageIndex)
        if didStartSecurityScope {
            book.textURL.stopAccessingSecurityScopedResource()
            didStartSecurityScope = false
        }
    }

    private func persist(pageIndex: Int) {
        guard pageRanges.isEmpty == false else { return }
        progressStore.update(
            bookID: book.id,
            pageIndex: min(max(pageIndex, 0), pageRanges.count - 1),
            pageCount: pageRanges.count
        )
    }
}
