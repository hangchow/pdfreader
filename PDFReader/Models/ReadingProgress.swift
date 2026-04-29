import Foundation

struct ReadingProgress: Codable, Equatable {
    var pageIndex: Int
    var pageCount: Int
    var updatedAt: Date

    var normalizedPageIndex: Int {
        guard pageCount > 0 else { return max(0, pageIndex) }
        return min(max(0, pageIndex), pageCount - 1)
    }

    var currentPageDisplay: Int {
        guard pageCount > 0 else { return 0 }
        return normalizedPageIndex + 1
    }

    var fraction: Double {
        guard pageCount > 0 else { return 0 }
        return Double(normalizedPageIndex + 1) / Double(pageCount)
    }

    var percentText: String {
        guard pageCount > 0 else { return "0%" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    var pageDisplayText: String {
        "\(currentPageDisplay)/\(pageCount)"
    }
}
