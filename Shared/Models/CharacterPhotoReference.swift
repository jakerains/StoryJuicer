import CoreGraphics
import Foundation

struct CharacterPhotoReference: Identifiable, Sendable {
    let id: UUID
    var name: String
    var photo: CGImage
    /// JPEG data for API upload.
    var photoData: Data
    var role: String = ""

    init(id: UUID = UUID(), name: String, photo: CGImage, photoData: Data, role: String = "") {
        self.id = id
        self.name = name
        self.photo = photo
        self.photoData = photoData
        self.role = role
    }
}
