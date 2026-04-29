import PDFKit
import SwiftUI
import UIKit

struct BookCardView: View {
    let book: PDFBook
    let progress: ReadingProgress?
    let generationProgress: Double?

    @State private var coverImage: UIImage?
    @State private var didFailLoadingCover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover
                .frame(maxWidth: .infinity)
                .aspectRatio(0.68, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)

            if let generationProgress {
                generationStatus(progress: generationProgress)
            } else if let progress, progress.pageCount > 0 {
                Text(progress.pageDisplayText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func generationStatus(progress: Double) -> some View {
        let normalizedProgress = min(max(progress, 0), 1)

        return VStack(alignment: .leading, spacing: 5) {
            Text("正在格式转换，请不要退出App")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: 8) {
                ProgressView(value: normalizedProgress)
                    .tint(.blue)

                Text("\(Int(normalizedProgress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                fallbackCover
            }
        }
        .task(id: book.id) {
            await loadCoverIfNeeded()
        }
    }

    private var fallbackCover: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.37, blue: 0.20),
                    Color(red: 0.99, green: 0.68, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if book.pdfURL == nil {
                Text(book.title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .minimumScaleFactor(0.55)
                    .padding(16)
            } else {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func loadCoverIfNeeded() async {
        guard coverImage == nil, didFailLoadingCover == false, let pdfURL = book.pdfURL else {
            return
        }

        let image = await Self.loadCoverImage(from: pdfURL)
        guard !Task.isCancelled else { return }

        if let image {
            coverImage = image
        } else {
            didFailLoadingCover = true
        }
    }

    private nonisolated static func loadCoverImage(from pdfURL: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let openedPDF = pdfURL.startAccessingSecurityScopedResource()
            defer {
                if openedPDF {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
            }

            guard let document = PDFDocument(url: pdfURL), let page = document.page(at: 0) else {
                return nil
            }

            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else {
                return nil
            }

            let targetWidth: CGFloat = 360
            let scale = targetWidth / bounds.width
            let targetSize = CGSize(width: targetWidth, height: bounds.height * scale)

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: targetSize))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: targetSize.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
        }.value
    }
}
