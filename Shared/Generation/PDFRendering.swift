import Foundation
import CoreGraphics

protocol PDFRendering {
    func render(storybook: StoryBook, images: [Int: CGImage], format: BookFormat) -> Data
}
