import SwiftUI
import AppKit

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
}
