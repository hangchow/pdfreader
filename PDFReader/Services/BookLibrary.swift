import Foundation
import UIKit

@MainActor
final class BookLibrary: ObservableObject {
    enum State: Equatable {
        case needsFolder
        case loading
        case ready
        case empty
        case failed(String)
    }

    @Published private(set) var books: [PDFBook] = []
    @Published private(set) var folderURL: URL?
    @Published private(set) var state: State = .loading
    @Published private(set) var requestedBook: PDFBook?
    @Published private(set) var generationProgressByBookID: [String: Double] = [:]
    @Published private(set) var generationErrorMessage: String?

    private let bookmarkStore = FolderBookmarkStore()
    private var activeFolderURL: URL?
    private var activeFolderAccessStarted = false
    private var refreshTask: Task<Void, Never>?
    private var generationTasks: [String: Task<Void, Never>] = [:]

    deinit {
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = false
        }
        if activeFolderAccessStarted {
            activeFolderURL?.stopAccessingSecurityScopedResource()
        }
    }

    func load() {
        do {
            guard let url = try bookmarkStore.resolve() else {
                state = .needsFolder
                return
            }
            setFolder(url)
            refresh()
        } catch {
            bookmarkStore.clear()
            state = .needsFolder
        }
    }

    func chooseFolder(_ url: URL) {
        setFolder(url)
        refresh()

        do {
            try bookmarkStore.save(folderURL: url)
        } catch {
            bookmarkStore.clear()
        }
    }

    func refresh() {
        guard let folderURL else {
            state = .needsFolder
            return
        }

        state = .loading
        refreshTask?.cancel()

        refreshTask = Task {
            let scannedBooks = await Self.scanBooks(in: folderURL)
            guard !Task.isCancelled else { return }
            books = scannedBooks
            state = scannedBooks.isEmpty ? .empty : .ready
        }
    }

    func openBook(_ book: PDFBook) {
        guard generationTasks[book.id] == nil else {
            return
        }

        if FileManager.default.fileExists(atPath: book.textURL.path) {
            requestedBook = book
            return
        }

        guard let pdfURL = book.pdfURL else {
            generationErrorMessage = "没有找到同名 PDF，无法生成 TXT。"
            return
        }

        generationProgressByBookID[book.id] = 0
        generationErrorMessage = nil
        UIApplication.shared.isIdleTimerDisabled = true

        generationTasks[book.id] = Task { [weak self] in
            defer {
                self?.generationProgressByBookID[book.id] = nil
                self?.generationTasks[book.id] = nil
                self?.updateIdleTimer()
            }

            do {
                try await PDFTextExtractor.generateTextFile(from: pdfURL, to: book.textURL, useSecurityScopedResources: true) { progress in
                    await MainActor.run {
                        self?.generationProgressByBookID[book.id] = progress
                    }
                }

                guard !Task.isCancelled else { return }
                self?.requestedBook = book
            } catch {
                guard !Task.isCancelled else { return }
                self?.generationErrorMessage = error.localizedDescription
            }
        }
    }

    func clearOpenRequest() {
        requestedBook = nil
    }

    func clearGenerationError() {
        generationErrorMessage = nil
    }

    private func setFolder(_ url: URL) {
        if activeFolderURL != url {
            if activeFolderAccessStarted {
                activeFolderURL?.stopAccessingSecurityScopedResource()
            }
            activeFolderURL = url
            activeFolderAccessStarted = url.startAccessingSecurityScopedResource()
        }
        folderURL = url
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = generationTasks.isEmpty == false
    }

    private nonisolated static func scanBooks(in folderURL: URL) async -> [PDFBook] {
        await Task.detached(priority: .userInitiated) {
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
            guard let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            var candidates: [String: BookCandidate] = [:]
            for case let fileURL as URL in enumerator {
                let isPDF = fileURL.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame
                let isText = fileURL.pathExtension.localizedCaseInsensitiveCompare("txt") == .orderedSame
                guard isPDF || isText else {
                    continue
                }

                let values = try? fileURL.resourceValues(forKeys: keys)
                guard values?.isRegularFile == true else {
                    continue
                }

                let key = fileURL.deletingPathExtension().standardizedFileURL.path
                var candidate = candidates[key] ?? BookCandidate(title: fileURL.deletingPathExtension().lastPathComponent)
                let fileInfo = BookFileInfo(
                    url: fileURL,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedDate: values?.contentModificationDate
                )

                if isPDF {
                    candidate.pdf = fileInfo
                } else {
                    candidate.text = fileInfo
                }
                candidates[key] = candidate
            }

            let books = candidates.values.compactMap { candidate -> PDFBook? in
                guard let primaryFile = candidate.pdf ?? candidate.text else {
                    return nil
                }

                return PDFBook(
                    id: primaryFile.url.standardizedFileURL.path,
                    title: candidate.title,
                    url: primaryFile.url,
                    fileSize: primaryFile.fileSize,
                    modifiedDate: candidate.modifiedDate,
                    pageCount: 0
                )
            }

            return books.sorted {
                let left = $0.modifiedDate ?? .distantPast
                let right = $1.modifiedDate ?? .distantPast
                if left == right {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return left > right
            }
        }.value
    }

}

private struct BookFileInfo {
    let url: URL
    let fileSize: Int64
    let modifiedDate: Date?
}

private struct BookCandidate {
    let title: String
    var pdf: BookFileInfo?
    var text: BookFileInfo?

    var modifiedDate: Date? {
        let pdfDate = pdf?.modifiedDate ?? .distantPast
        let textDate = text?.modifiedDate ?? .distantPast
        let newestDate = max(pdfDate, textDate)
        return newestDate == .distantPast ? nil : newestDate
    }
}
