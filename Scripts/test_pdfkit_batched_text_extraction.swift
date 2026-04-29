import CoreGraphics
import Foundation
import PDFKit

@main
struct PDFKitBatchedTextExtractionTest {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 4 else {
            fputs("usage: test_pdfkit_batched_text_extraction <pdf> <txt> <batch_size> [max_pages]\n", stderr)
            Foundation.exit(2)
        }

        let pdfURL = URL(fileURLWithPath: arguments[1])
        let outputURL = URL(fileURLWithPath: arguments[2])
        let batchSize = max(Int(arguments[3]) ?? 1, 1)
        let maxPages = arguments.count >= 5 ? Int(arguments[4]) : nil

        guard let cgDocument = CGPDFDocument(pdfURL as CFURL), cgDocument.numberOfPages > 0 else {
            fputs("cannot open pdf\n", stderr)
            Foundation.exit(1)
        }

        let pageCount = min(maxPages ?? cgDocument.numberOfPages, cgDocument.numberOfPages)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: outputURL)
        defer {
            try? fileHandle.close()
        }

        let startedAt = Date()
        var nonEmptyPages = 0
        var totalCharacters = 0

        var batchStart = 0
        while batchStart < pageCount {
            try autoreleasepool {
                guard let document = PDFDocument(url: pdfURL) else {
                    throw ExtractionError.cannotOpenPDF
                }

                let batchEnd = min(batchStart + batchSize, pageCount)
                for index in batchStart..<batchEnd {
                    let text = document.page(at: index)?.string ?? ""
                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedText.isEmpty == false {
                        nonEmptyPages += 1
                        totalCharacters += trimmedText.count
                    }

                    let finalText = trimmedText.isEmpty ? "此页没有可提取文本" : trimmedText
                    let separator = index == pageCount - 1 ? "" : "\n\u{000C}\n"
                    if let data = (finalText + separator).data(using: .utf8) {
                        try fileHandle.write(contentsOf: data)
                    }

                    let currentPage = index + 1
                    if currentPage == pageCount || currentPage.isMultiple(of: 250) {
                        let elapsed = Date().timeIntervalSince(startedAt)
                        print("page=\(currentPage)/\(pageCount) nonEmpty=\(nonEmptyPages) chars=\(totalCharacters) elapsed=\(String(format: "%.2f", elapsed))s")
                    }
                }
            }

            batchStart += batchSize
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        print("done pages=\(pageCount) nonEmpty=\(nonEmptyPages) chars=\(totalCharacters) elapsed=\(String(format: "%.2f", elapsed))s output=\(outputURL.path)")
    }
}

private enum ExtractionError: Error {
    case cannotOpenPDF
}
