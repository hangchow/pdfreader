import XCTest
@testable import PDFReader

final class TextCleanerTests: XCTestCase {
    func testJoinsWrappedNarrationLinesFromLordOfMysteriesSample() {
        let text = """
        　　光怪陆离满是低语的梦境迅速支离破碎，熟睡中的周明瑞只觉脑
        袋抽痛异常，仿佛被人用棒子狠狠抡了一下，不，更像是遭尖锐的物
        品刺入太阳穴并伴随有搅动!
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            "　　光怪陆离满是低语的梦境迅速支离破碎，熟睡中的周明瑞只觉脑袋抽痛异常，仿佛被人用棒子狠狠抡了一下，不，更像是遭尖锐的物品刺入太阳穴并伴随有搅动!"
        )
    }

    func testJoinsWhenNextLineStartsWithPunctuationFromSample() {
        let text = """
        本身不是收尾，只是一个接续，一个承上启下
        ，也是另一个方面
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            "本身不是收尾，只是一个接续，一个承上启下，也是另一个方面"
        )
    }

    func testJoinsWhenPunctuationLineHasLeadingAsciiWhitespace() {
        let text = """
        本身不是收尾，只是一个接续，一个承上启下
          ，也是另一个方面
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            "本身不是收尾，只是一个接续，一个承上启下，也是另一个方面"
        )
    }

    func testKeepsLineBreakAfterSentenceEndingBeforeNewIndentedParagraph() {
        let text = """
        　　“所有人都会死，包括我。”
        　　下一段内容继续。
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            "　　“所有人都会死，包括我。”\n　　下一段内容继续。"
        )
    }

    func testKeepsIndentedParagraphStartEvenWhenPreviousLineHasNoEndingPunctuation() {
        let text = """
        　　红绯 章一第
        　　痛!
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            "　　红绯 章一第\n　　痛!"
        )
    }

    func testKeepsLineBreakAfterChapterHeadingFromIssueThree() {
        let text = """
        　　
        第九十五章 王女
        不喜欢绰号
        """

        XCTAssertEqual(
            TextCleaner.cleanExtractedText(text),
            """
            　　
            第九十五章 王女
            不喜欢绰号
            """
        )
    }

    func testKeepsPageSeparatorBoundaries() {
        let text = "上一页最后一行\n\u{000C}\n下一页第一行"

        XCTAssertEqual(TextCleaner.cleanExtractedText(text), text)
    }

    func testEnsuresFullWidthIndentForChineseParagraphsWhenLoadingText() {
        let text = """
        没有缩进的中文段落。
          “带 ASCII 空格的对话段落。”
        　　已有全角缩进的段落。
        English paragraph.
        """

        XCTAssertEqual(
            TextCleaner.ensureParagraphIndents(in: text),
            """
            　　没有缩进的中文段落。
            　　“带 ASCII 空格的对话段落。”
            　　已有全角缩进的段落。
            English paragraph.
            """
        )
    }

    func testDoesNotIndentUnindentedWrappedContinuationLinesWhenLoadingText() {
        let text = """
        　　光怪陆离满是低语的梦境迅速支离破碎，熟睡中的周明瑞只觉脑
        袋抽痛异常，仿佛被人用棒子狠狠抡了一下。
        新段落应该补缩进。
        """

        XCTAssertEqual(
            TextCleaner.ensureParagraphIndents(in: text),
            """
            　　光怪陆离满是低语的梦境迅速支离破碎，熟睡中的周明瑞只觉脑
            袋抽痛异常，仿佛被人用棒子狠狠抡了一下。
            　　新段落应该补缩进。
            """
        )
    }
}
