import Foundation
import CoreGraphics

protocol EPUBRendering {
    func render(storybook: StoryBook, images: [Int: CGImage], format: BookFormat) -> Data
}
