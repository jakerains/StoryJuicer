import Foundation
import CoreGraphics
import AppKit
import PDFKit
import SwiftUI

struct MacPDFRenderer: PDFRendering {

    private let dpi: CGFloat = 300
    private let marginInches: CGFloat = 0.75

    func render(storybook: StoryBook, images: [Int: CGImage], format: BookFormat) -> Data {
        let pageSize = format.printDimensions
        let margin = marginInches * dpi
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageSize.width - (margin * 2),
            height: pageSize.height - (margin * 2)
        )

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        // Title page
        renderTitlePage(context: context, storybook: storybook, coverImage: images[0],
                       pageSize: pageSize, contentRect: contentRect)

        // Story pages
        for page in storybook.pages {
            renderContentPage(context: context, page: page, image: images[page.pageNumber],
                            pageSize: pageSize, contentRect: contentRect,
                            pageNumber: page.pageNumber, totalPages: storybook.pages.count)
        }

        // "The End" page
        renderEndPage(context: context, storybook: storybook,
                     pageSize: pageSize, contentRect: contentRect)

        context.closePDF()

        return pdfData as Data
    }

    // MARK: - Title Page

    private func renderTitlePage(context: CGContext, storybook: StoryBook,
                                  coverImage: CGImage?, pageSize: CGSize,
                                  contentRect: CGRect) {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)

        // Cover illustration
        if let cover = coverImage {
            let imageHeight = contentRect.height * 0.55
            let imageRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - imageHeight,
                width: contentRect.width,
                height: imageHeight
            )
            let fitted = fitImage(cover, in: imageRect)
            context.draw(cover, in: fitted)
        }

        // Title
        let titleFont = CTFontCreateWithName("Georgia-Bold" as CFString, 72, nil)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(Color.sjText).cgColor
        ]
        let titleString = NSAttributedString(string: storybook.title, attributes: titleAttr)
        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString)
        let titleRect = CGRect(
            x: contentRect.minX,
            y: contentRect.minY + contentRect.height * 0.1,
            width: contentRect.width,
            height: contentRect.height * 0.25
        )
        let titlePath = CGPath(rect: titleRect, transform: nil)
        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, 0), titlePath, nil)
        CTFrameDraw(titleFrame, context)

        // Author line
        let authorFont = CTFontCreateWithName("Georgia-Italic" as CFString, 36, nil)
        let authorAttr: [NSAttributedString.Key: Any] = [
            .font: authorFont,
            .foregroundColor: NSColor.secondaryLabelColor.cgColor
        ]
        let authorString = NSAttributedString(string: storybook.authorLine, attributes: authorAttr)
        let authorFramesetter = CTFramesetterCreateWithAttributedString(authorString)
        let authorRect = CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width,
            height: contentRect.height * 0.08
        )
        let authorPath = CGPath(rect: authorRect, transform: nil)
        let authorFrame = CTFramesetterCreateFrame(authorFramesetter, CFRangeMake(0, 0), authorPath, nil)
        CTFrameDraw(authorFrame, context)

        context.endPDFPage()
    }

    // MARK: - Content Page

    private func renderContentPage(context: CGContext, page: StoryPage,
                                    image: CGImage?, pageSize: CGSize,
                                    contentRect: CGRect, pageNumber: Int, totalPages: Int) {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)

        // Illustration (~60% top)
        if let img = image {
            let imageHeight = contentRect.height * 0.58
            let imageRect = CGRect(
                x: contentRect.minX,
                y: contentRect.maxY - imageHeight,
                width: contentRect.width,
                height: imageHeight
            )
            let fitted = fitImage(img, in: imageRect)
            context.draw(img, in: fitted)
        }

        // Story text (~35% below)
        let textFont = CTFontCreateWithName("Georgia" as CFString, 42, nil)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 14
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor.cgColor,
            .paragraphStyle: paragraphStyle
        ]
        let textString = NSAttributedString(string: page.text, attributes: textAttr)
        let textFramesetter = CTFramesetterCreateWithAttributedString(textString)
        let textRect = CGRect(
            x: contentRect.minX + 40,
            y: contentRect.minY + contentRect.height * 0.05,
            width: contentRect.width - 80,
            height: contentRect.height * 0.33
        )
        let textPath = CGPath(rect: textRect, transform: nil)
        let textFrame = CTFramesetterCreateFrame(textFramesetter, CFRangeMake(0, 0), textPath, nil)
        CTFrameDraw(textFrame, context)

        // Page number
        let pageNumFont = CTFontCreateWithName("Georgia" as CFString, 28, nil)
        let pageNumAttr: [NSAttributedString.Key: Any] = [
            .font: pageNumFont,
            .foregroundColor: NSColor.secondaryLabelColor.cgColor
        ]
        let pageNumStr = NSAttributedString(string: "\(pageNumber)", attributes: pageNumAttr)
        let pageNumLine = CTLineCreateWithAttributedString(pageNumStr)
        let pageNumBounds = CTLineGetBoundsWithOptions(pageNumLine, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: (pageSize.width - pageNumBounds.width) / 2,
            y: marginInches * dpi * 0.4
        )
        CTLineDraw(pageNumLine, context)

        context.endPDFPage()
    }

    // MARK: - End Page

    private func renderEndPage(context: CGContext, storybook: StoryBook,
                                pageSize: CGSize, contentRect: CGRect) {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)

        // "The End"
        let endFont = CTFontCreateWithName("Georgia-Bold" as CFString, 80, nil)
        let endAttr: [NSAttributedString.Key: Any] = [
            .font: endFont,
            .foregroundColor: NSColor(Color.sjText).cgColor
        ]
        let endString = NSAttributedString(string: "The End", attributes: endAttr)
        let endLine = CTLineCreateWithAttributedString(endString)
        let endBounds = CTLineGetBoundsWithOptions(endLine, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: (pageSize.width - endBounds.width) / 2,
            y: pageSize.height * 0.55
        )
        CTLineDraw(endLine, context)

        // Moral
        let moralFont = CTFontCreateWithName("Georgia-Italic" as CFString, 36, nil)
        let moralParagraphStyle = NSMutableParagraphStyle()
        moralParagraphStyle.alignment = .center
        moralParagraphStyle.lineSpacing = 10
        let moralAttr: [NSAttributedString.Key: Any] = [
            .font: moralFont,
            .foregroundColor: NSColor.secondaryLabelColor.cgColor,
            .paragraphStyle: moralParagraphStyle
        ]
        let moralString = NSAttributedString(string: storybook.moral, attributes: moralAttr)
        let moralFramesetter = CTFramesetterCreateWithAttributedString(moralString)
        let moralRect = CGRect(
            x: contentRect.minX + 80,
            y: pageSize.height * 0.3,
            width: contentRect.width - 160,
            height: pageSize.height * 0.2
        )
        let moralPath = CGPath(rect: moralRect, transform: nil)
        let moralFrame = CTFramesetterCreateFrame(moralFramesetter, CFRangeMake(0, 0), moralPath, nil)
        CTFrameDraw(moralFrame, context)

        context.endPDFPage()
    }

    // MARK: - Helper

    private func fitImage(_ image: CGImage, in rect: CGRect) -> CGRect {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let rectAspect = rect.width / rect.height

        if imageAspect > rectAspect {
            // Image is wider — fit to width
            let height = rect.width / imageAspect
            let y = rect.midY - height / 2
            return CGRect(x: rect.minX, y: y, width: rect.width, height: height)
        } else {
            // Image is taller — fit to height
            let width = rect.height * imageAspect
            let x = rect.midX - width / 2
            return CGRect(x: x, y: rect.minY, width: width, height: rect.height)
        }
    }
}
