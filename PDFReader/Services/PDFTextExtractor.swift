import CoreGraphics
import Foundation
import PDFKit

enum PDFTextExtractorError: LocalizedError {
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

enum PDFTextExtractor {
    static let defaultBatchSize = 50

    static func generateTextFile(
        from pdfURL: URL,
        to textURL: URL,
        batchSize: Int = defaultBatchSize,
        maxPages: Int? = nil,
        useSecurityScopedResources: Bool = false,
        onProgress: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let openedPDF = useSecurityScopedResources && pdfURL.startAccessingSecurityScopedResource()
            let folderURL = textURL.deletingLastPathComponent()
            let openedFolder = useSecurityScopedResources && folderURL.startAccessingSecurityScopedResource()
            defer {
                if openedPDF {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
                if openedFolder {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            guard let pageCounter = CGPDFDocument(pdfURL as CFURL), pageCounter.numberOfPages > 0 else {
                throw PDFTextExtractorError.unreadablePDF
            }

            let fileManager = FileManager.default
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let tempURL = folderURL.appendingPathComponent(".\(textURL.deletingPathExtension().lastPathComponent).pdfreader.tmp")
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }

            guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
                throw PDFTextExtractorError.cannotCreateTextFile
            }

            let fileHandle = try FileHandle(forWritingTo: tempURL)
            defer {
                try? fileHandle.close()
                try? fileManager.removeItem(at: tempURL)
            }

            let pageCount = min(maxPages ?? pageCounter.numberOfPages, pageCounter.numberOfPages)
            let safeBatchSize = max(batchSize, 1)
            let progressStep = max(1, min(10, pageCount / 200))

            var batchStart = 0
            while batchStart < pageCount {
                try Task.checkCancellation()
                var progressToReport: Double?

                try autoreleasepool {
                    guard let document = PDFDocument(url: pdfURL) else {
                        throw PDFTextExtractorError.unreadablePDF
                    }

                    let batchEnd = min(batchStart + safeBatchSize, pageCount)
                    for index in batchStart..<batchEnd {
                        try Task.checkCancellation()

                        let extractedText = document.page(at: index)?.string ?? ""
                        let cleanedText = TextCleaner.cleanExtractedText(extractedText)
                        let pageText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "此页没有可提取文本" : cleanedText
                        let separator = index == pageCount - 1 ? "" : "\n\u{000C}\n"

                        guard let data = (pageText + separator).data(using: .utf8) else {
                            throw PDFTextExtractorError.cannotCreateTextFile
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

                batchStart += safeBatchSize
            }

            try fileHandle.close()
            if fileManager.fileExists(atPath: textURL.path) {
                try fileManager.removeItem(at: textURL)
            }
            try fileManager.moveItem(at: tempURL, to: textURL)
        }.value
    }

}
