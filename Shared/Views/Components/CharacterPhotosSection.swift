import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct CharacterPhotosSection: View {
    @Binding var characterPhotos: [CharacterPhotoReference]
    static let maxPhotos = 3

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.sjCoral)

                Text("Character Photos")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjGlassInk)

                Spacer()

                Text("\(characterPhotos.count)/\(Self.maxPhotos)")
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjMuted)
            }

            Text("Upload photos of people or pets to make them characters in your story.")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    if characterPhotos.count < Self.maxPhotos {
                        addPhotoButton
                    }

                    ForEach($characterPhotos) { $photo in
                        photoCard(photo: $photo)
                    }
                }
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.xSmall)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .background(Color.sjReadableCard.opacity(0.6))
        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.card)
                .strokeBorder(Color.sjBorder.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - Add Photo Button

    private var addPhotoButton: some View {
        Button {
            pickPhoto()
        } label: {
            VStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.sjCoral)

                Text("Add Photo")
                    .font(StoryJuicerTypography.settingsMeta.weight(.medium))
                    .foregroundStyle(Color.sjCoral)
            }
            .frame(width: 80, height: 100)
            .background(Color.sjCoral.opacity(0.08))
            .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
            .overlay {
                RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                    .strokeBorder(Color.sjCoral.opacity(0.3), lineWidth: 1, antialiased: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Card

    private func photoCard(photo: Binding<CharacterPhotoReference>) -> some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            ZStack(alignment: .topTrailing) {
                #if os(macOS)
                Image(nsImage: NSImage(cgImage: photo.wrappedValue.photo, size: NSSize(width: 80, height: 80)))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                #endif

                Button {
                    characterPhotos.removeAll { $0.id == photo.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.sjCoral)
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }

            TextField("Name", text: photo.name)
                .font(StoryJuicerTypography.settingsMeta)
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .textFieldStyle(.plain)
        }
        .frame(width: 90)
    }

    // MARK: - Photo Picker

    private func pickPhoto() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a photo of a person or pet"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Convert to JPEG data for API upload
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

        let name = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .prefix(20)

        let reference = CharacterPhotoReference(
            name: String(name),
            photo: cgImage,
            photoData: jpegData
        )
        characterPhotos.append(reference)
        #endif
    }
}
