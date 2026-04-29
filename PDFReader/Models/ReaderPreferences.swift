import SwiftUI

enum ReaderFontChoice: String, CaseIterable, Codable, Identifiable {
    case system
    case serif
    case rounded
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统"
        case .serif: "衬线"
        case .rounded: "圆体"
        case .monospaced: "等宽"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}

struct ReaderPreferences: Codable, Equatable {
    var fontChoice: ReaderFontChoice = .system
    var textSize: Double = 18

    static let textSizeRange: ClosedRange<Double> = 14...30
}
