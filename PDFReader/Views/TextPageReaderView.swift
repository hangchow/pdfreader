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
                    cachedText: pageCache[index],
                    didFailLoading: failedPageIndices.contains(index),
                    preferences: preferences
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
    let cachedText: String?
    let didFailLoading: Bool
    let preferences: ReaderPreferences

    var body: some View {
        ScrollView {
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
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .padding(.bottom, 44)
        }
        .contentShape(Rectangle())
        .background(Color(.systemBackground))
    }
}
