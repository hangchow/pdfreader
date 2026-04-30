import Foundation

enum TextCleaner {
    static func cleanExtractedText(_ text: String) -> String {
        removeWrappedLineBreaks(in: normalizeChineseParagraphIndents(in: text))
    }

    static func removeWrappedLineBreaks(in text: String) -> String {
        let lineBreakTrimmedText = text.trimmingCharacters(in: .newlines)
        let lines = lineBreakTrimmedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { rawLine -> String in
                var line = String(rawLine)
                if line.hasSuffix("\r") {
                    line.removeLast()
                }
                return line
            }

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
        let lineBreakTrimmedText = text.trimmingCharacters(in: .newlines)
        let lines = lineBreakTrimmedText.split(separator: "\n", omittingEmptySubsequences: false)

        return lines.map { line in
            var textLine = String(line)
            if textLine.hasSuffix("\r") {
                textLine.removeLast()
            }

            if textLine.hasPrefix("\u{3000}\u{3000}") {
                return textLine
            }

            let leadingSpaceCount = textLine.prefix { $0 == " " || $0 == "\t" }.count
            guard leadingSpaceCount > 0 else {
                return textLine
            }

            let contentStart = textLine.index(textLine.startIndex, offsetBy: leadingSpaceCount)
            let content = textLine[contentStart...]
            guard content.first?.isLikelyCJK == true else {
                return textLine
            }

            return "\u{3000}\u{3000}" + content
        }.joined(separator: "\n")
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
        line.hasPrefix("\u{3000}\u{3000}") ||
            line.hasPrefix("  ") ||
            line.hasPrefix("\t")
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
}
