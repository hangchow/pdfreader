import Foundation

struct PDFBook: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let fileSize: Int64
    let modifiedDate: Date?
    let pageCount: Int

    var pdfURL: URL? {
        guard url.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame else {
            return nil
        }
        return url
    }

    var textURL: URL {
        url.deletingPathExtension().appendingPathExtension("txt")
    }

    var subtitle: String {
        var parts: [String] = []
        if pageCount > 0 {
            parts.append("\(pageCount) 页")
        }
        if fileSize > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }
}
