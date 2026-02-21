import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

struct MacExportView {
    /// Present an NSSavePanel and export the storybook as PDF.
    @MainActor
    static func exportPDF(
        storybook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat,
        renderer: PDFRendering
    ) {
        let panel = NSSavePanel()
        panel.title = "Export Storybook as PDF"
        panel.nameFieldStringValue = "\(storybook.title).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let pdfData = renderer.render(storybook: storybook, images: images, format: format)

        do {
            try pdfData.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not save the PDF: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    /// Present an NSSavePanel and export the storybook as EPUB.
    @MainActor
    static func exportEPUB(
        storybook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat,
        renderer: EPUBRendering
    ) {
        let epubType = UTType(filenameExtension: "epub") ?? UTType(exportedAs: "org.idpf.epub-container")

        let panel = NSSavePanel()
        panel.title = "Export Storybook as EPUB"
        panel.nameFieldStringValue = "\(storybook.title).epub"
        panel.allowedContentTypes = [epubType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let epubData = renderer.render(storybook: storybook, images: images, format: format)

        do {
            try epubData.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not save the EPUB: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    /// Present an NSSavePanel and export the current page as a PNG image.
    @MainActor
    static func exportPageImage(
        pageIndex: Int,
        storybook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat,
        renderer: PageImageRenderer
    ) {
        let totalPages = storybook.pages.count + 2
        let isTitle = pageIndex == 0
        let isEnd = pageIndex == totalPages - 1

        let pageSuffix: String
        if isTitle {
            pageSuffix = "Cover"
        } else if isEnd {
            pageSuffix = "The End"
        } else {
            pageSuffix = "Page \(pageIndex)"
        }

        let panel = NSSavePanel()
        panel.title = "Export Page as Image"
        panel.nameFieldStringValue = "\(storybook.title) - \(pageSuffix).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let cgImage = renderer.renderPage(
            pageIndex: pageIndex,
            storybook: storybook,
            images: images,
            format: format
        ) else {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not render the page image."
            alert.alertStyle = .critical
            alert.runModal()
            return
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not create the image file at the selected location."
            alert.alertStyle = .critical
            alert.runModal()
            return
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        if !CGImageDestinationFinalize(destination) {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not write the PNG image to disk."
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}
