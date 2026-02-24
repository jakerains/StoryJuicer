import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Builds an EPUB 3.0 Fixed Layout archive from a StoryBook and its images.
///
/// The visual styling intentionally mirrors `StoryPDFRenderer`:
/// cream `#F6EEDF` background, Georgia fonts, coral `#B4543A` accents,
/// 55 % image / 30 % text layout, and `border-radius: 8px` on images.
struct StoryEPUBRenderer: EPUBRendering {

    func render(storybook: StoryBook, images: [Int: CGImage], format: BookFormat) -> Data {
        let vw = Int(format.dimensions.width)
        let vh = Int(format.dimensions.height)

        var zip = ZIPBuilder()

        // 1. mimetype — must be first, stored uncompressed, no extra field
        zip.addStored(path: "mimetype", data: Data("application/epub+zip".utf8))

        // 2. META-INF/container.xml
        zip.addDeflated(path: "META-INF/container.xml", data: Data(containerXML.utf8))

        // 3. CSS
        zip.addDeflated(path: "OEBPS/styles.css", data: Data(stylesheet(vw: vw, vh: vh).utf8))

        // 4. Images — JPEG at 0.85 quality, stored (already compressed)
        var imageManifestEntries: [(id: String, href: String)] = []

        if let cover = images[0] {
            // Flatten title + author text onto the cover image so EPUB readers
            // show the title on the bookshelf thumbnail (they use cover-image, not the HTML page).
            let flatCover = compositeCoverImage(cover, title: storybook.title, author: storybook.authorLine)
            if let jpeg = cgImageToJPEGData(flatCover) {
                zip.addStored(path: "OEBPS/images/cover.jpg", data: jpeg)
                imageManifestEntries.append((id: "img-cover", href: "images/cover.jpg"))
            }
        }

        for page in storybook.pages {
            if let img = images[page.pageNumber], let jpeg = cgImageToJPEGData(img) {
                let filename = "page-\(page.pageNumber).jpg"
                zip.addStored(path: "OEBPS/images/\(filename)", data: jpeg)
                imageManifestEntries.append((id: "img-\(page.pageNumber)", href: "images/\(filename)"))
            }
        }

        // 4b. Stamp image for end page (PNG to preserve transparency)
        let hasStamp: Bool
        if let stampImage = loadStampImage(), let stampPNG = cgImageToPNGData(stampImage) {
            zip.addStored(path: "OEBPS/images/stamp.png", data: stampPNG)
            imageManifestEntries.append((id: "img-stamp", href: "images/stamp.png"))
            hasStamp = true
        } else {
            hasStamp = false
        }

        // 5. XHTML pages
        let coverXHTML = coverPage(storybook: storybook, hasCoverImage: images[0] != nil,
                                   vw: vw, vh: vh)
        zip.addDeflated(path: "OEBPS/cover.xhtml", data: Data(coverXHTML.utf8))

        for page in storybook.pages {
            let xhtml = contentPage(page: page, hasImage: images[page.pageNumber] != nil,
                                    totalPages: storybook.pages.count, vw: vw, vh: vh)
            zip.addDeflated(path: "OEBPS/page-\(page.pageNumber).xhtml", data: Data(xhtml.utf8))
        }

        let endXHTML = endPage(storybook: storybook, hasStamp: hasStamp, vw: vw, vh: vh)
        zip.addDeflated(path: "OEBPS/end.xhtml", data: Data(endXHTML.utf8))

        // 6. Navigation document
        let nav = navigationDocument(storybook: storybook)
        zip.addDeflated(path: "OEBPS/toc.xhtml", data: Data(nav.utf8))

        // 7. OPF package document
        let opf = packageDocument(storybook: storybook, imageEntries: imageManifestEntries,
                                  vw: vw, vh: vh)
        zip.addDeflated(path: "OEBPS/content.opf", data: Data(opf.utf8))

        return zip.finalize()
    }

    // MARK: - Container XML

    private let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """

    // MARK: - CSS

    private func stylesheet(vw: Int, vh: Int) -> String {
        """
        @viewport { width: \(vw)px; height: \(vh)px; }
        html, body {
            margin: 0; padding: 0;
            width: \(vw)px; height: \(vh)px;
            overflow: hidden;
            background: #F6EEDF;
            font-family: Georgia, 'Times New Roman', serif;
            color: #1E1510;
        }
        .page {
            width: \(vw)px; height: \(vh)px;
            display: flex; flex-direction: column;
            align-items: center; justify-content: center;
            box-sizing: border-box;
            padding: 54px;
        }
        .cover-page {
            text-align: center;
        }
        .cover-page img {
            max-width: 100%;
            max-height: 55%;
            border-radius: 8px;
            object-fit: contain;
        }
        .cover-title {
            font-size: 30px; font-weight: bold;
            color: #1E1510;
            margin-top: 24px; line-height: 1.25;
        }
        .cover-author {
            font-size: 14px; font-style: italic;
            color: #6B5A4C;
            margin-top: 8px;
        }
        .divider {
            width: 70%;
            height: 1px;
            background: #B4543A;
            margin: 16px auto;
            opacity: 0.6;
        }
        .content-page { text-align: center; }
        .content-page img {
            max-width: 100%;
            max-height: 55%;
            border-radius: 8px;
            object-fit: contain;
        }
        .story-text {
            font-size: 17px;
            line-height: 1.6;
            color: #1E1510;
            margin-top: 16px;
            text-align: center;
            max-width: 90%;
        }
        .page-number {
            font-size: 10px;
            color: #6B5A4C;
            margin-top: auto;
            padding-top: 8px;
        }
        .end-page { text-align: center; }
        .end-ornament {
            font-size: 14px;
            color: #B4543A;
            margin: 12px 0;
        }
        .end-title {
            font-size: 36px; font-weight: bold;
            color: #1E1510;
        }
        .end-moral {
            font-size: 14px; font-style: italic;
            color: #6B5A4C;
            line-height: 1.6;
            margin-top: 16px;
            max-width: 80%;
        }
        .stamp {
            width: 80px; height: 80px;
            opacity: 0.7;
            margin-top: 24px;
        }
        """
    }

    // MARK: - Cover Page

    private func coverPage(storybook: StoryBook, hasCoverImage: Bool,
                            vw: Int, vh: Int) -> String {
        let imageTag = hasCoverImage
            ? "<img src=\"images/cover.jpg\" alt=\"Cover illustration\"/>"
            : ""

        return xhtmlDocument(title: xmlEscape(storybook.title), vw: vw, vh: vh, body: """
            <div class="page cover-page">
                \(imageTag)
                <div class="divider"></div>
                <div class="cover-title">\(xmlEscape(storybook.title))</div>
                <div class="cover-author">\(xmlEscape(storybook.authorLine))</div>
            </div>
            """)
    }

    // MARK: - Content Page

    private func contentPage(page: StoryPage, hasImage: Bool,
                              totalPages: Int, vw: Int, vh: Int) -> String {
        let imageTag = hasImage
            ? "<img src=\"images/page-\(page.pageNumber).jpg\" alt=\"Page \(page.pageNumber) illustration\"/>"
            : ""

        return xhtmlDocument(title: "Page \(page.pageNumber)", vw: vw, vh: vh, body: """
            <div class="page content-page">
                \(imageTag)
                <div class="divider"></div>
                <div class="story-text">\(xmlEscape(page.text))</div>
                <div class="page-number">\(page.pageNumber)</div>
            </div>
            """)
    }

    // MARK: - End Page

    private func endPage(storybook: StoryBook, hasStamp: Bool, vw: Int, vh: Int) -> String {
        let stampHTML = hasStamp
            ? "<img class=\"stamp\" src=\"images/stamp.png\" alt=\"StoryFox stamp\"/>"
            : ""

        return xhtmlDocument(title: "The End", vw: vw, vh: vh, body: """
            <div class="page end-page">
                <div class="end-ornament">\u{2014}  \u{25C6}  \u{2014}</div>
                <div class="end-title">The End</div>
                <div class="end-ornament">\u{2014}  \u{25C6}  \u{2014}</div>
                <div class="end-moral">\(xmlEscape(storybook.moral))</div>
                \(stampHTML)
            </div>
            """)
    }

    // MARK: - Navigation Document

    private func navigationDocument(storybook: StoryBook) -> String {
        var navItems = "<li><a href=\"cover.xhtml\">Cover</a></li>\n"
        for page in storybook.pages {
            navItems += "            <li><a href=\"page-\(page.pageNumber).xhtml\">Page \(page.pageNumber)</a></li>\n"
        }
        navItems += "            <li><a href=\"end.xhtml\">The End</a></li>"

        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head><title>Table of Contents</title></head>
            <body>
              <nav epub:type="toc" id="toc">
                <h1>Contents</h1>
                <ol>
                    \(navItems)
                </ol>
              </nav>
            </body>
            </html>
            """
    }

    // MARK: - OPF Package Document

    private func packageDocument(storybook: StoryBook,
                                  imageEntries: [(id: String, href: String)],
                                  vw: Int, vh: Int) -> String {
        let bookID = UUID().uuidString

        // Manifest
        var manifestItems = """
                <item id="nav" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="css" href="styles.css" media-type="text/css"/>
                <item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>

            """

        for page in storybook.pages {
            manifestItems += "        <item id=\"page-\(page.pageNumber)\" href=\"page-\(page.pageNumber).xhtml\" media-type=\"application/xhtml+xml\"/>\n"
        }
        manifestItems += "        <item id=\"end\" href=\"end.xhtml\" media-type=\"application/xhtml+xml\"/>\n"

        for entry in imageEntries {
            let mediaType = entry.href.hasSuffix(".png") ? "image/png" : "image/jpeg"
            if entry.id == "img-cover" {
                manifestItems += "        <item id=\"\(entry.id)\" href=\"\(entry.href)\" media-type=\"\(mediaType)\" properties=\"cover-image\"/>\n"
            } else {
                manifestItems += "        <item id=\"\(entry.id)\" href=\"\(entry.href)\" media-type=\"\(mediaType)\"/>\n"
            }
        }

        // Spine
        var spineItems = "        <itemref idref=\"cover\"/>\n"
        for page in storybook.pages {
            spineItems += "        <itemref idref=\"page-\(page.pageNumber)\"/>\n"
        }
        spineItems += "        <itemref idref=\"end\"/>"

        // EPUB 2 backward-compatible cover meta (for Kindle/older readers)
        let hasCoverMeta = imageEntries.contains(where: { $0.id == "img-cover" })
            ? "\n            <meta name=\"cover\" content=\"img-cover\"/>"
            : ""

        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="bookid">urn:uuid:\(bookID)</dc:identifier>
                <dc:title>\(xmlEscape(storybook.title))</dc:title>
                <dc:creator>\(xmlEscape(storybook.authorLine))</dc:creator>
                <dc:language>en</dc:language>
                <meta property="dcterms:modified">\(iso8601Now())</meta>
                <meta property="rendition:layout">pre-paginated</meta>
                <meta property="rendition:spread">auto</meta>\(hasCoverMeta)
              </metadata>
              <manifest>
            \(manifestItems)    </manifest>
              <spine>
            \(spineItems)
              </spine>
            </package>
            """
    }

    // MARK: - Helpers

    private func xhtmlDocument(title: String, vw: Int, vh: Int, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <meta charset="UTF-8"/>
            <meta name="viewport" content="width=\(vw), height=\(vh)"/>
            <title>\(title)</title>
            <link rel="stylesheet" type="text/css" href="styles.css"/>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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

    private func iso8601Now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // EPUB requires seconds precision without fractional seconds
        let full = formatter.string(from: Date())
        // Trim to minute precision as required by EPUB 3 dcterms:modified
        if let tIndex = full.firstIndex(of: "T") {
            let dateStr = full[full.startIndex..<tIndex]
            let timeAndZone = full[full.index(after: tIndex)...]
            // Take HH:MM:SS portion
            let timeParts = timeAndZone.prefix(8)
            return "\(dateStr)T\(timeParts)Z"
        }
        return full
    }

    // MARK: - Cover Image Compositing

    /// Draw title and author text onto the cover illustration so the EPUB cover-image
    /// asset shows the book title on the bookshelf in iBooks / other readers.
    ///
    /// Layout: image fills the full canvas, title sits in the lower third over a
    /// semi-transparent gradient scrim, author line below the title.
    private func compositeCoverImage(_ image: CGImage, title: String, author: String) -> CGImage {
        let w = image.width
        let h = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        let fullRect = CGRect(x: 0, y: 0, width: w, height: h)

        // Draw the original illustration
        ctx.draw(image, in: fullRect)

        // Draw a gradient scrim over the bottom 40% for text legibility
        let scrimHeight = CGFloat(h) * 0.4
        let scrimRect = CGRect(x: 0, y: 0, width: CGFloat(w), height: scrimHeight)
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.85),
                CGColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.saveGState()
        ctx.clip(to: scrimRect)
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: scrimHeight),
            options: []
        )
        ctx.restoreGState()

        // Scale font size relative to image dimensions
        let scale = CGFloat(w) / 1024.0
        let titleFontSize = max(36 * scale, 24)
        let authorFontSize = max(18 * scale, 14)
        let margin = 40 * scale

        // Draw title
        let titleFont = CTFontCreateWithName("Georgia-Bold" as CFString, titleFontSize, nil)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        titleParagraphStyle.lineBreakMode = .byWordWrapping
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            .paragraphStyle: titleParagraphStyle
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttr)
        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleStr)

        // Measure title height
        let titleConstraint = CGSize(width: CGFloat(w) - margin * 2, height: scrimHeight * 0.6)
        let titleSize = CTFramesetterSuggestFrameSizeWithConstraints(
            titleFramesetter, CFRangeMake(0, 0), nil, titleConstraint, nil
        )

        // Position title above author line, near bottom
        let authorLineHeight = authorFontSize * 1.5
        let titleY = margin + authorLineHeight + 8 * scale
        let titleRect = CGRect(
            x: margin,
            y: titleY,
            width: CGFloat(w) - margin * 2,
            height: titleSize.height + titleFontSize * 0.5
        )
        let titlePath = CGPath(rect: titleRect, transform: nil)
        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, 0), titlePath, nil)
        CTFrameDraw(titleFrame, ctx)

        // Draw author line
        let authorFont = CTFontCreateWithName("Georgia-Italic" as CFString, authorFontSize, nil)
        let authorParagraphStyle = NSMutableParagraphStyle()
        authorParagraphStyle.alignment = .center
        let authorAttr: [NSAttributedString.Key: Any] = [
            .font: authorFont,
            .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 0.75),
            .paragraphStyle: authorParagraphStyle
        ]
        let authorStr = NSAttributedString(string: author, attributes: authorAttr)
        let authorLine = CTLineCreateWithAttributedString(authorStr)
        let authorBounds = CTLineGetBoundsWithOptions(authorLine, .useOpticalBounds)
        ctx.textPosition = CGPoint(
            x: (CGFloat(w) - authorBounds.width) / 2,
            y: margin
        )
        CTLineDraw(authorLine, ctx)

        return ctx.makeImage() ?? image
    }
}
