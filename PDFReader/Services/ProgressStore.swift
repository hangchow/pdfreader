import Foundation

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var progressByBookID: [String: ReadingProgress]

    private let defaults = UserDefaults.standard
    private let key = "pdfreader.reading.progress"

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: ReadingProgress].self, from: data) {
            progressByBookID = decoded
        } else {
            progressByBookID = [:]
        }
    }

    func progress(for book: PDFBook) -> ReadingProgress? {
        progressByBookID[book.id]
    }

    func pageIndex(for book: PDFBook) -> Int {
        progress(for: book)?.normalizedPageIndex ?? 0
    }

    func update(bookID: String, pageIndex: Int, pageCount: Int) {
        let progress = ReadingProgress(
            pageIndex: pageIndex,
            pageCount: pageCount,
            updatedAt: Date()
        )
        progressByBookID[bookID] = progress
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progressByBookID) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
