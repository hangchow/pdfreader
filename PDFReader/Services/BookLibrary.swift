import CoreGraphics
import Foundation
import PDFKit
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
                try await Self.generateTextFile(from: pdfURL, to: book.textURL) { progress in
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

    private nonisolated static func generateTextFile(
        from pdfURL: URL,
        to textURL: URL,
        onProgress: @escaping @Sendable (Double) async -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let openedPDF = pdfURL.startAccessingSecurityScopedResource()
            let openedFolder = textURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
            defer {
                if openedPDF {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
                if openedFolder {
                    textURL.deletingLastPathComponent().stopAccessingSecurityScopedResource()
                }
            }

            guard let pageCounter = CGPDFDocument(pdfURL as CFURL), pageCounter.numberOfPages > 0 else {
                throw TextGenerationError.unreadablePDF
            }

            let fileManager = FileManager.default
            let tempURL = textURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(textURL.deletingPathExtension().lastPathComponent).pdfreader.tmp")

            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }

            guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
                throw TextGenerationError.cannotCreateTextFile
            }

            let fileHandle = try FileHandle(forWritingTo: tempURL)
            defer {
                try? fileHandle.close()
                try? fileManager.removeItem(at: tempURL)
            }

            let pageCount = pageCounter.numberOfPages
            let batchSize = 50
            let progressStep = max(1, min(10, pageCount / 200))

            var batchStart = 0
            while batchStart < pageCount {
                try Task.checkCancellation()
                var progressToReport: Double?

                try autoreleasepool {
                    guard let document = PDFDocument(url: pdfURL) else {
                        throw TextGenerationError.unreadablePDF
                    }

                    let batchEnd = min(batchStart + batchSize, pageCount)
                    for index in batchStart..<batchEnd {
                        try Task.checkCancellation()

                        let extractedText = document.page(at: index)?.string ?? ""
                        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let pageText = trimmedText.isEmpty ? "此页没有可提取文本" : trimmedText
                        let separator = index == pageCount - 1 ? "" : "\n\u{000C}\n"

                        guard let data = (pageText + separator).data(using: .utf8) else {
                            throw TextGenerationError.cannotCreateTextFile
                        }

                        try fileHandle.write(contentsOf: data)
                        if (index + 1).isMultiple(of: progressStep) || index == pageCount - 1 {
                            progressToReport = Double(index + 1) / Double(pageCount)
                        }
                    }
                }

                if let progressToReport {
                    await onProgress(progressToReport)
                }

                batchStart += batchSize
            }

            try fileHandle.close()
            if fileManager.fileExists(atPath: textURL.path) {
                try fileManager.removeItem(at: textURL)
            }
            try fileManager.moveItem(at: tempURL, to: textURL)
        }.value
    }
}

private enum TextGenerationError: LocalizedError {
    case unreadablePDF
    case cannotCreateTextFile

    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return "这个 PDF 无法提取文字。"
        case .cannotCreateTextFile:
            return "无法在同目录生成 TXT 文件。"
        }
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
