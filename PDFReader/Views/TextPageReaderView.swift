import SwiftUI

struct TextPageReaderView: View {
    let textURL: URL
    let pageRanges: [TextPageRange]
    @Binding var currentPageIndex: Int
    let preferences: ReaderPreferences

    @State private var pageCache: [Int: String] = [:]
    @State private var failedPageIndices: Set<Int> = []

    var body: some View {
        TabView(selection: $currentPageIndex) {
            ForEach(pageRanges.indices, id: \.self) { index in
                TextPageContentView(
                    pageIndex: index,
                    pageCount: pageRanges.count,
                    cachedText: pageCache[index],
                    didFailLoading: failedPageIndices.contains(index),
                    preferences: preferences,
                    onPageChange: { targetIndex in
                        withAnimation(.snappy(duration: 0.2)) {
                            currentPageIndex = targetIndex
                        }
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .task(id: currentPageIndex) {
            await loadVisiblePages()
        }
    }

    @MainActor
    private func loadVisiblePages() async {
        let requestedPageIndex = currentPageIndex
        let orderedTargetIndices = [
            requestedPageIndex,
            requestedPageIndex - 1,
            requestedPageIndex + 1
        ].filter { pageRanges.indices.contains($0) }
        let targetIndices = Set(orderedTargetIndices)

        pageCache = pageCache.filter { targetIndices.contains($0.key) }
        failedPageIndices = failedPageIndices.intersection(targetIndices)

        for index in orderedTargetIndices where pageCache[index] == nil && failedPageIndices.contains(index) == false {
            do {
                let loadedText = try await TextPageFile.loadPage(from: textURL, range: pageRanges[index])
                guard !Task.isCancelled, requestedPageIndex == currentPageIndex else { return }
                pageCache[index] = loadedText
            } catch {
                guard !Task.isCancelled, requestedPageIndex == currentPageIndex else { return }
                failedPageIndices.insert(index)
            }
        }
    }
}

private struct TextPageContentView: View {
    let pageIndex: Int
    let pageCount: Int
    let cachedText: String?
    let didFailLoading: Bool
    let preferences: ReaderPreferences
    let onPageChange: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Group {
                    if let cachedText {
                        Text(cachedText)
                            .font(.system(size: preferences.textSize, design: preferences.fontChoice.design))
                            .lineSpacing(preferences.textSize * 0.28)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if didFailLoading {
                        Text("此页暂时无法读取")
                            .font(.system(size: preferences.textSize, design: preferences.fontChoice.design))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }

                PageTurnControls(
                    canGoPrevious: pageIndex > 0,
                    canGoNext: pageIndex < pageCount - 1,
                    goPrevious: {
                        onPageChange(max(pageIndex - 1, 0))
                    },
                    goNext: {
                        onPageChange(min(pageIndex + 1, pageCount - 1))
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .padding(.bottom, 52)
        }
        .contentShape(Rectangle())
        .background(Color(.systemBackground))
    }
}

private struct PageTurnControls: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let goPrevious: () -> Void
    let goNext: () -> Void

    var body: some View {
        HStack(spacing: 36) {
            Button(action: goPrevious) {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 62, height: 46)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoPrevious)
            .opacity(canGoPrevious ? 1 : 0.28)
            .accessibilityLabel("上一页")

            Button(action: goNext) {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 62, height: 46)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.28)
            .accessibilityLabel("下一页")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
}
