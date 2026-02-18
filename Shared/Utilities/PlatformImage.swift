import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage

extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#else
import UIKit
public typealias PlatformImage = UIImage
#endif
