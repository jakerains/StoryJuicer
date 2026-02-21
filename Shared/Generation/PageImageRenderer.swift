import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Renders a single storybook page as a high-resolution bitmap (`CGImage`)
/// at 300 DPI print dimensions, matching the visual language of `StoryPDFRenderer`.
struct PageImageRenderer {

    // MARK: - Colors (static — no light/dark mode in exported images)

    private let creamBg = CGColor(red: 0.965, green: 0.933, blue: 0.875, alpha: 1.0)
    private let darkText = CGColor(red: 0.118, green: 0.082, blue: 0.063, alpha: 1.0)
    private let mutedText = CGColor(red: 0.420, green: 0.353, blue: 0.298, alpha: 1.0)
    private let accentCoral = CGColor(red: 0.706, green: 0.329, blue: 0.227, alpha: 1.0)

    // MARK: - Public

    /// Render a single page of the storybook as a 300 DPI `CGImage`.
    ///
    /// - Parameters:
    ///   - pageIndex: The viewer page index (0 = title, 1…N = story pages, N+1 = end page).
    ///   - storybook: The storybook model.
    ///   - images: Dictionary of `CGImage` keyed by page number (0 = cover).
    ///   - format: The book format (determines output dimensions).
    /// - Returns: A rendered `CGImage`, or `nil` on failure.
    func renderPage(
        pageIndex: Int,
        storybook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat
    ) -> CGImage? {
        let pixelSize = format.printDimensions
        let screenSize = format.dimensions
        let scale = pixelSize.width / screenSize.width

        // Base layout constants (at 72 DPI), scaled up for print
        let margin = 54 * scale
        let imageCornerRadius = 8 * scale

        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pixelSize.width - (margin * 2),
            height: pixelSize.height - (margin * 2)
        )

        guard let context = CGContext(
            data: nil,
            width: Int(pixelSize.width),
            height: Int(pixelSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let totalPages = storybook.pages.count + 2
        let isTitle = pageIndex == 0
        let isEnd = pageIndex == totalPages - 1

        fillBackground(context: context, size: pixelSize)

        if isTitle {
            renderTitlePage(
                context: context, storybook: storybook,
                coverImage: images[0], pageSize: pixelSize,
                contentRect: contentRect, scale: scale,
                imageCornerRadius: imageCornerRadius
            )
        } else if isEnd {
            renderEndPage(
                context: context, storybook: storybook,
                pageSize: pixelSize, contentRect: contentRect,
                scale: scale
            )
        } else {
            let storyPageIndex = pageIndex - 1
            guard storyPageIndex >= 0, storyPageIndex < storybook.pages.count else { return nil }
            let page = storybook.pages[storyPageIndex]
            renderContentPage(
                context: context, page: page,
                image: images[page.pageNumber], pageSize: pixelSize,
                contentRect: contentRect, pageNumber: page.pageNumber,
                totalPages: storybook.pages.count, scale: scale,
                imageCornerRadius: imageCornerRadius
            )
        }

        return context.makeImage()
    }

    // MARK: - Title Page

    private func renderTitlePage(
        context: CGContext, storybook: StoryBook,
        coverImage: CGImage?, pageSize: CGSize,
        contentRect: CGRect, scale: CGFloat,
        imageCornerRadius: CGFloat
    ) {
        if let cover = coverImage {
            let imageHeight = contentRect.height * 0.55
            let imageRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - imageHeight,
                width: contentRect.width,
                height: imageHeight
            )
            drawRoundedImage(cover, in: imageRect, context: context, cornerRadius: imageCornerRadius)
        }

        let dividerY = contentRect.minY + contentRect.height * 0.38
        drawDivider(context: context, y: dividerY, contentRect: contentRect, scale: scale)

        let titleFont = CTFontCreateWithName("Georgia-Bold" as CFString, 30 * scale, nil)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        titleParagraphStyle.lineSpacing = 4 * scale
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: darkText,
            .paragraphStyle: titleParagraphStyle
        ]
        let titleString = NSAttributedString(string: storybook.title, attributes: titleAttr)
        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString)
        let titleRect = CGRect(
            x: contentRect.minX + 20 * scale,
            y: contentRect.minY + contentRect.height * 0.12,
            width: contentRect.width - 40 * scale,
            height: contentRect.height * 0.24
        )
        let titlePath = CGPath(rect: titleRect, transform: nil)
        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, 0), titlePath, nil)
        CTFrameDraw(titleFrame, context)

        let authorFont = CTFontCreateWithName("Georgia-Italic" as CFString, 14 * scale, nil)
        let authorParagraphStyle = NSMutableParagraphStyle()
        authorParagraphStyle.alignment = .center
        let authorAttr: [NSAttributedString.Key: Any] = [
            .font: authorFont,
            .foregroundColor: mutedText,
            .paragraphStyle: authorParagraphStyle
        ]
        let authorString = NSAttributedString(string: storybook.authorLine, attributes: authorAttr)
        let authorFramesetter = CTFramesetterCreateWithAttributedString(authorString)
        let authorRect = CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width,
            height: contentRect.height * 0.1
        )
        let authorPath = CGPath(rect: authorRect, transform: nil)
        let authorFrame = CTFramesetterCreateFrame(authorFramesetter, CFRangeMake(0, 0), authorPath, nil)
        CTFrameDraw(authorFrame, context)

        drawStampBottomRight(context: context, pageSize: pageSize, scale: scale)
    }

    // MARK: - Content Page

    private func renderContentPage(
        context: CGContext, page: StoryPage,
        image: CGImage?, pageSize: CGSize,
        contentRect: CGRect, pageNumber: Int,
        totalPages: Int, scale: CGFloat,
        imageCornerRadius: CGFloat
    ) {
        if let img = image {
            let imageHeight = contentRect.height * 0.55
            let imageRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - imageHeight,
                width: contentRect.width,
                height: imageHeight
            )
            drawRoundedImage(img, in: imageRect, context: context, cornerRadius: imageCornerRadius)
        }

        let dividerY = contentRect.minY + contentRect.height * 0.38
        drawDivider(context: context, y: dividerY, contentRect: contentRect, scale: scale)

        let textFont = CTFontCreateWithName("Georgia" as CFString, 17 * scale, nil)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6 * scale
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: darkText,
            .paragraphStyle: paragraphStyle
        ]
        let textString = NSAttributedString(string: page.text, attributes: textAttr)
        let textFramesetter = CTFramesetterCreateWithAttributedString(textString)
        let textRect = CGRect(
            x: contentRect.minX + 16 * scale,
            y: contentRect.minY + contentRect.height * 0.06,
            width: contentRect.width - 32 * scale,
            height: contentRect.height * 0.30
        )
        let textPath = CGPath(rect: textRect, transform: nil)
        let textFrame = CTFramesetterCreateFrame(textFramesetter, CFRangeMake(0, 0), textPath, nil)
        CTFrameDraw(textFrame, context)

        let pageNumFont = CTFontCreateWithName("Georgia" as CFString, 10 * scale, nil)
        let pageNumAttr: [NSAttributedString.Key: Any] = [
            .font: pageNumFont,
            .foregroundColor: mutedText
        ]
        let pageNumStr = NSAttributedString(string: "\(pageNumber)", attributes: pageNumAttr)
        let pageNumLine = CTLineCreateWithAttributedString(pageNumStr)
        let pageNumBounds = CTLineGetBoundsWithOptions(pageNumLine, .useOpticalBounds)
        let margin = 54 * scale
        context.textPosition = CGPoint(
            x: (pageSize.width - pageNumBounds.width) / 2,
            y: margin * 0.45
        )
        CTLineDraw(pageNumLine, context)

        drawStampBottomRight(context: context, pageSize: pageSize, scale: scale)
    }

    // MARK: - End Page

    private func renderEndPage(
        context: CGContext, storybook: StoryBook,
        pageSize: CGSize, contentRect: CGRect,
        scale: CGFloat
    ) {
        drawOrnament(context: context, centerX: pageSize.width / 2,
                     y: pageSize.height * 0.62, fontSize: 14 * scale)

        let endFont = CTFontCreateWithName("Georgia-Bold" as CFString, 36 * scale, nil)
        let endAttr: [NSAttributedString.Key: Any] = [
            .font: endFont,
            .foregroundColor: darkText
        ]
        let endString = NSAttributedString(string: "The End", attributes: endAttr)
        let endLine = CTLineCreateWithAttributedString(endString)
        let endBounds = CTLineGetBoundsWithOptions(endLine, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: (pageSize.width - endBounds.width) / 2,
            y: pageSize.height * 0.55
        )
        CTLineDraw(endLine, context)

        drawOrnament(context: context, centerX: pageSize.width / 2,
                     y: pageSize.height * 0.50, fontSize: 14 * scale)

        let moralFont = CTFontCreateWithName("Georgia-Italic" as CFString, 14 * scale, nil)
        let moralParagraphStyle = NSMutableParagraphStyle()
        moralParagraphStyle.alignment = .center
        moralParagraphStyle.lineSpacing = 5 * scale
        let moralAttr: [NSAttributedString.Key: Any] = [
            .font: moralFont,
            .foregroundColor: mutedText,
            .paragraphStyle: moralParagraphStyle
        ]
        let moralString = NSAttributedString(string: storybook.moral, attributes: moralAttr)
        let moralFramesetter = CTFramesetterCreateWithAttributedString(moralString)
        let moralRect = CGRect(
            x: contentRect.minX + 40 * scale,
            y: pageSize.height * 0.35,
            width: contentRect.width - 80 * scale,
            height: pageSize.height * 0.13
        )
        let moralPath = CGPath(rect: moralRect, transform: nil)
        let moralFrame = CTFramesetterCreateFrame(moralFramesetter, CFRangeMake(0, 0), moralPath, nil)
        CTFrameDraw(moralFrame, context)

        // End page: stamp centered (matches PDF renderer)
        drawStampCentered(context: context, pageSize: pageSize, scale: scale)
    }

    // MARK: - Stamp

    private func drawStampBottomRight(context: CGContext, pageSize: CGSize, scale: CGFloat) {
        guard let stampImage = loadStampImage() else { return }
        let stampSize = 80 * scale   // ~320px at 300 DPI
        let margin = 54 * scale
        let stampRect = CGRect(
            x: pageSize.width - margin - stampSize,
            y: margin * 0.3,
            width: stampSize,
            height: stampSize
        )
        context.saveGState()
        context.setAlpha(0.7)
        context.draw(stampImage, in: stampRect)
        context.restoreGState()
    }

    private func drawStampCentered(context: CGContext, pageSize: CGSize, scale: CGFloat) {
        guard let stampImage = loadStampImage() else { return }
        let stampSize = 80 * scale
        let stampRect = CGRect(
            x: (pageSize.width - stampSize) / 2,
            y: pageSize.height * 0.12,
            width: stampSize,
            height: stampSize
        )
        context.saveGState()
        context.setAlpha(0.7)
        context.draw(stampImage, in: stampRect)
        context.restoreGState()
    }

    private func loadStampImage() -> CGImage? {
        #if os(macOS)
        guard let nsImage = NSImage(named: "StoryFoxStamp"),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
        #else
        guard let uiImage = UIImage(named: "StoryFoxStamp") else { return nil }
        return uiImage.cgImage
        #endif
    }

    // MARK: - Drawing Helpers

    private func fillBackground(context: CGContext, size: CGSize) {
        context.setFillColor(creamBg)
        context.fill(CGRect(origin: .zero, size: size))
    }

    private func drawRoundedImage(_ image: CGImage, in rect: CGRect, context: CGContext, cornerRadius: CGFloat) {
        let fitted = fitImage(image, in: rect)
        context.saveGState()
        let roundedPath = CGPath(roundedRect: fitted,
                                  cornerWidth: cornerRadius,
                                  cornerHeight: cornerRadius,
                                  transform: nil)
        context.addPath(roundedPath)
        context.clip()
        context.draw(image, in: fitted)
        context.restoreGState()
    }

    private func drawDivider(context: CGContext, y: CGFloat, contentRect: CGRect, scale: CGFloat) {
        let lineInset = contentRect.width * 0.15
        let leftStart = contentRect.minX + lineInset
        let rightEnd = contentRect.maxX - lineInset
        let centerX = contentRect.midX

        context.saveGState()
        context.setStrokeColor(accentCoral)
        context.setLineWidth(0.75 * scale)

        context.move(to: CGPoint(x: leftStart, y: y))
        context.addLine(to: CGPoint(x: centerX - 12 * scale, y: y))
        context.strokePath()

        context.move(to: CGPoint(x: centerX + 12 * scale, y: y))
        context.addLine(to: CGPoint(x: rightEnd, y: y))
        context.strokePath()

        let diamondSize = 3.5 * scale
        context.move(to: CGPoint(x: centerX, y: y + diamondSize))
        context.addLine(to: CGPoint(x: centerX + diamondSize, y: y))
        context.addLine(to: CGPoint(x: centerX, y: y - diamondSize))
        context.addLine(to: CGPoint(x: centerX - diamondSize, y: y))
        context.closePath()
        context.setFillColor(accentCoral)
        context.fillPath()

        context.restoreGState()
    }

    private func drawOrnament(context: CGContext, centerX: CGFloat, y: CGFloat, fontSize: CGFloat) {
        let ornamentFont = CTFontCreateWithName("Georgia" as CFString, fontSize, nil)
        let ornamentAttr: [NSAttributedString.Key: Any] = [
            .font: ornamentFont,
            .foregroundColor: accentCoral
        ]
        let ornamentStr = NSAttributedString(string: "\u{2014}  \u{25C6}  \u{2014}", attributes: ornamentAttr)
        let ornamentLine = CTLineCreateWithAttributedString(ornamentStr)
        let ornamentBounds = CTLineGetBoundsWithOptions(ornamentLine, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: centerX - ornamentBounds.width / 2,
            y: y
        )
        CTLineDraw(ornamentLine, context)
    }

    private func fitImage(_ image: CGImage, in rect: CGRect) -> CGRect {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let rectAspect = rect.width / rect.height

        if imageAspect > rectAspect {
            let height = rect.width / imageAspect
            let y = rect.midY - height / 2
            return CGRect(x: rect.minX, y: y, width: rect.width, height: height)
        } else {
            let width = rect.height * imageAspect
            let x = rect.midX - width / 2
            return CGRect(x: x, y: rect.minY, width: width, height: rect.height)
        }
    }
}
