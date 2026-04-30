import Foundation

struct TextPageRange: Hashable {
    let startOffset: UInt64
    let endOffset: UInt64

    var byteCount: Int {
        Int(endOffset - startOffset)
    }
}

enum TextPageFile {
    private static let pageSeparatorByte: UInt8 = 0x0C
    private static let readChunkSize = 1024 * 1024

    static func buildPageRanges(from textURL: URL) async throws -> [TextPageRange] {
        try await Task.detached(priority: .userInitiated) {
            let openedText = textURL.startAccessingSecurityScopedResource()
            defer {
                if openedText {
                    textURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileHandle = try FileHandle(forReadingFrom: textURL)
            defer {
                try? fileHandle.close()
            }

            var ranges: [TextPageRange] = []
            var currentPageStart: UInt64 = 0
            var absoluteOffset: UInt64 = 0

            while let data = try fileHandle.read(upToCount: readChunkSize), data.isEmpty == false {
                data.withUnsafeBytes { rawBuffer in
                    let bytes = rawBuffer.bindMemory(to: UInt8.self)
                    for index in bytes.indices where bytes[index] == pageSeparatorByte {
                        let separatorOffset = absoluteOffset + UInt64(index)
                        ranges.append(TextPageRange(startOffset: currentPageStart, endOffset: separatorOffset))
                        currentPageStart = separatorOffset + 1
                    }
                }
                absoluteOffset += UInt64(data.count)
            }

            ranges.append(TextPageRange(startOffset: currentPageStart, endOffset: absoluteOffset))
            return ranges
        }.value
    }

    static func loadPage(from textURL: URL, range: TextPageRange) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let openedText = textURL.startAccessingSecurityScopedResource()
            defer {
                if openedText {
                    textURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileHandle = try FileHandle(forReadingFrom: textURL)
            defer {
                try? fileHandle.close()
            }

            try fileHandle.seek(toOffset: range.startOffset)
            let data = try fileHandle.read(upToCount: range.byteCount) ?? Data()
            let rawText = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let text = rawText.trimmingCharacters(in: .newlines)
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "此页没有可提取文本" : text
        }.value
    }
}
