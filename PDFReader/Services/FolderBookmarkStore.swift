import Foundation

struct FolderBookmarkStore {
    private let defaults = UserDefaults.standard
    private let key = "icloud.pdfreader.folder.bookmark"

    func save(folderURL: URL) throws {
        let data = try folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    func resolve() throws -> URL? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try save(folderURL: url)
        }

        return url
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
