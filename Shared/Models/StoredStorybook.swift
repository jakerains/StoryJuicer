import Foundation
import SwiftData
import CoreGraphics

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Model
final class StoredStorybook {
    var id: UUID
    var title: String
    var authorLine: String
    var moral: String
    var createdAt: Date
    var formatRawValue: String
    var styleRawValue: String
    var coverImageData: Data?
    var isFavorite: Bool = false
    var displayOrder: Int = 0
    var characterDescriptions: String = ""
    var originalConcept: String = ""
    var textProviderRawValue: String = ""
    var imageProviderRawValue: String = ""
    var textModelName: String = ""
    var imageModelName: String = ""

    @Relationship(deleteRule: .cascade)
    var pages: [StoredPage]

    init(
        title: String,
        authorLine: String,
        moral: String,
        characterDescriptions: String = "",
        originalConcept: String = "",
        textProviderRawValue: String = "",
        imageProviderRawValue: String = "",
        textModelName: String = "",
        imageModelName: String = "",
        format: BookFormat,
        style: IllustrationStyle,
        coverImageData: Data? = nil,
        pages: [StoredPage] = [],
        isFavorite: Bool = false,
        displayOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.authorLine = authorLine
        self.moral = moral
        self.characterDescriptions = characterDescriptions
        self.originalConcept = originalConcept
        self.textProviderRawValue = textProviderRawValue
        self.imageProviderRawValue = imageProviderRawValue
        self.textModelName = textModelName
        self.imageModelName = imageModelName
        self.createdAt = Date()
        self.formatRawValue = format.rawValue
        self.styleRawValue = style.rawValue
        self.coverImageData = coverImageData
        self.pages = pages
        self.isFavorite = isFavorite
        self.displayOrder = displayOrder
    }

    var format: BookFormat {
        BookFormat(rawValue: formatRawValue) ?? .standard
    }

    var style: IllustrationStyle {
        IllustrationStyle(rawValue: styleRawValue) ?? .illustration
    }
}

@Model
final class StoredPage {
    var pageNumber: Int
    var text: String
    var imagePrompt: String
    var imageData: Data?

    init(pageNumber: Int, text: String, imagePrompt: String, imageData: Data? = nil) {
        self.pageNumber = pageNumber
        self.text = text
        self.imagePrompt = imagePrompt
        self.imageData = imageData
    }
}

// MARK: - Conversion Helpers

extension StoredStorybook {
    /// Create a StoredStorybook from a generated StoryBook + images.
    @MainActor
    static func from(
        storyBook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat,
        style: IllustrationStyle,
        concept: String = "",
        textProvider: String = "",
        imageProvider: String = "",
        textModelName: String = "",
        imageModelName: String = ""
    ) -> StoredStorybook {
        let coverData = images[0].flatMap { cgImageToPNGData($0) }

        let storedPages = storyBook.pages.map { page in
            let imageData = images[page.pageNumber].flatMap { cgImageToPNGData($0) }
            return StoredPage(
                pageNumber: page.pageNumber,
                text: page.text,
                imagePrompt: page.imagePrompt,
                imageData: imageData
            )
        }

        return StoredStorybook(
            title: storyBook.title,
            authorLine: storyBook.authorLine,
            moral: storyBook.moral,
            characterDescriptions: storyBook.characterDescriptions,
            originalConcept: concept,
            textProviderRawValue: textProvider,
            imageProviderRawValue: imageProvider,
            textModelName: textModelName,
            imageModelName: imageModelName,
            format: format,
            style: style,
            coverImageData: coverData,
            pages: storedPages
        )
    }

    /// Convert back to a StoryBook for the reader view.
    func toStoryBook() -> StoryBook {
        let storyPages = pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .map { page in
                StoryPage(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: page.imagePrompt
                )
            }

        return StoryBook(
            title: title,
            authorLine: authorLine,
            moral: moral,
            characterDescriptions: characterDescriptions,
            pages: storyPages
        )
    }

    /// Reconstruct the images dictionary from stored data.
    func toImages() -> [Int: CGImage] {
        var result: [Int: CGImage] = [:]

        if let coverData = coverImageData, let cgImage = cgImageFromData(coverData) {
            result[0] = cgImage
        }

        for page in pages {
            if let data = page.imageData, let cgImage = cgImageFromData(data) {
                result[page.pageNumber] = cgImage
            }
        }

        return result
    }
}

// MARK: - Image Conversion Utilities

func cgImageToPNGData(_ cgImage: CGImage) -> Data? {
    #if os(macOS)
    let nsImage = NSImage(cgImage: cgImage)
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmapRep.representation(using: .png, properties: [:])
    #else
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage.pngData()
    #endif
}

func cgImageToJPEGData(_ cgImage: CGImage, quality: Double = 0.85) -> Data? {
    #if os(macOS)
    let nsImage = NSImage(cgImage: cgImage)
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    #else
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage.jpegData(compressionQuality: quality)
    #endif
}

private func cgImageFromData(_ data: Data) -> CGImage? {
    #if os(macOS)
    guard let nsImage = NSImage(data: data),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    return cgImage
    #else
    guard let uiImage = UIImage(data: data) else { return nil }
    return uiImage.cgImage
    #endif
}
