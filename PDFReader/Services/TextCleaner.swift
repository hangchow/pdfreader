import Foundation

enum TextCleaner {
    private static let paragraphIndent = "\u{3000}\u{3000}"

    static func cleanExtractedText(_ text: String) -> String {
        removeWrappedLineBreaks(in: normalizeChineseParagraphIndents(in: text))
    }

    static func ensureParagraphIndents(in text: String) -> String {
        let lineBreakTrimmedText = text.trimmingCharacters(in: .newlines)
        var previousContentLine: String?

        return normalizedLines(in: lineBreakTrimmedText).map { line in
            let indented = indentedLine(line, previousContentLine: previousContentLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                previousContentLine = nil
            } else {
                previousContentLine = line
            }
            return indented
        }.joined(separator: "\n")
    }

    static func removeWrappedLineBreaks(in text: String) -> String {
        let lineBreakTrimmedText = text.trimmingCharacters(in: .newlines)
        let lines = normalizedLines(in: lineBreakTrimmedText)

        var mergedLines: [String] = []
        for line in lines {
            guard let previousLine = mergedLines.last else {
                mergedLines.append(line)
                continue
            }

            if shouldRemoveLineBreak(previousLine: previousLine, nextLine: line) {
                mergedLines[mergedLines.count - 1] = previousLine + lineForJoining(line)
            } else {
                mergedLines.append(line)
            }
        }

        return mergedLines.joined(separator: "\n")
    }

    static func normalizeChineseParagraphIndents(in text: String) -> String {
        mapLines(in: text) { line in
            guard line.hasParagraphIndent == false else {
                return line
            }

            let leadingSpaceCount = line.prefix { $0 == " " || $0 == "\t" }.count
            guard leadingSpaceCount > 0 else {
                return line
            }

            let contentStart = line.index(line.startIndex, offsetBy: leadingSpaceCount)
            let content = String(line[contentStart...])
            guard content.startsLikeChineseParagraph else {
                return line
            }

            return paragraphIndent + content
        }
    }

    private static func shouldRemoveLineBreak(previousLine: String, nextLine: String) -> Bool {
        if previousLine.trimmingCharacters(in: .whitespaces).isEmpty ||
            nextLine.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }

        if previousLine.contains("\u{000C}") || nextLine.contains("\u{000C}") {
            return false
        }

        if startsWithLeadingPunctuation(nextLine) {
            return true
        }

        if startsWithParagraphIndent(nextLine) {
            return false
        }

        return hasSentenceEndingPause(previousLine) == false
    }

    private static func hasSentenceEndingPause(_ line: String) -> Bool {
        var trimmedLine = line.trimmingCharacters(in: .whitespaces)
        while let last = trimmedLine.last, Self.closingPunctuation.contains(last) {
            trimmedLine.removeLast()
        }

        guard let last = trimmedLine.last else {
            return false
        }

        return Self.sentenceEndingPunctuation.contains(last)
    }

    private static func startsWithLeadingPunctuation(_ line: String) -> Bool {
        guard let first = line.firstNonWhitespace else {
            return false
        }

        return Self.leadingPunctuation.contains(first)
    }

    private static func lineForJoining(_ line: String) -> String {
        startsWithLeadingPunctuation(line) ? line.trimmingLeadingWhitespace() : line
    }

    private static func startsWithParagraphIndent(_ line: String) -> Bool {
        line.hasParagraphIndent ||
            line.hasPrefix("  ") ||
            line.hasPrefix("\t")
    }

    private static func indentedLine(_ line: String, previousContentLine: String?) -> String {
        guard line.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            return line
        }

        if line.hasParagraphIndent {
            return line
        }

        if line.hasAsciiParagraphIndent {
            let content = line.trimmingLeadingWhitespace()
            return content.startsLikeChineseParagraph ? paragraphIndent + content : line
        }

        guard previousContentLine == nil || hasSentenceEndingPause(previousContentLine ?? "") else {
            return line
        }

        let content = line.trimmingLeadingWhitespace()
        guard content.startsLikeChineseParagraph else {
            return line
        }

        return paragraphIndent + content
    }

    private static func normalizedLines(in text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { rawLine in
            var line = String(rawLine)
            if line.hasSuffix("\r") {
                line.removeLast()
            }
            return line
        }
    }

    private static func mapLines(in text: String, transform: (String) -> String) -> String {
        let lineBreakTrimmedText = text.trimmingCharacters(in: .newlines)
        return normalizedLines(in: lineBreakTrimmedText).map(transform).joined(separator: "\n")
    }

    private static let sentenceEndingPunctuation = Set<Character>(["。", ".", "！", "!", "？", "?", "…"])
    private static let closingPunctuation = Set<Character>(["”", "\"", "’", "'", "）", ")", "》", ">", "】", "]", "」", "』"])
    private static let leadingPunctuation = Set<Character>([
        "，", ",", "。", ".", "！", "!", "？", "?", "；", ";", "：", ":", "、",
        "”", "\"", "’", "'", "）", ")", "》", ">", "】", "]", "」", "』"
    ])
}

private extension Character {
    var isLikelyCJK: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }
}

private extension String {
    var firstNonWhitespace: Character? {
        first { $0 != " " && $0 != "\t" }
    }

    func trimmingLeadingWhitespace() -> String {
        guard let firstContentIndex = firstIndex(where: { $0 != " " && $0 != "\t" }) else {
            return ""
        }

        return String(self[firstContentIndex...])
    }

    var hasParagraphIndent: Bool {
        hasPrefix("\u{3000}\u{3000}")
    }

    var hasAsciiParagraphIndent: Bool {
        hasPrefix("  ") || hasPrefix("\t")
    }

    var startsLikeChineseParagraph: Bool {
        guard let firstContent = firstNonWhitespace else {
            return false
        }

        return firstContent.isLikelyCJK || Self.chineseParagraphLeadingCharacters.contains(firstContent)
    }

    private static let chineseParagraphLeadingCharacters = Set<Character>([
        "“", "\"", "‘", "'", "「", "『", "（", "(", "《", "〈", "【", "["
    ])
}
