import SwiftUI
import CoreGraphics

struct PageThumbnail: View {
    let pageNumber: Int
    let image: CGImage?
    let isGenerating: Bool
    var isSelected: Bool = false
    var aspectRatio: CGFloat = 1.0
    var onRegenerate: (() -> Void)? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.18)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
            } else if isGenerating {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Painting")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sjGlassCard(tint: .sjGlassSoft.opacity(0.35), cornerRadius: StoryJuicerGlassTokens.Radius.thumbnail)
            } else {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Color.sjMuted)

                    if let onRegenerate {
                        Button {
                            onRegenerate()
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(StoryJuicerTypography.uiFootnoteStrong)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.sjCoral)
                        .controlSize(.mini)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sjGlassCard(tint: .sjGlassWeak, cornerRadius: StoryJuicerGlassTokens.Radius.thumbnail)
            }
        }
        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.thumbnail))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.thumbnail)
                .strokeBorder(
                    isSelected ? Color.sjCoral.opacity(0.85) : Color.sjBorder.opacity(0.45),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .overlay(alignment: .bottomTrailing) {
            Text("\(pageNumber)")
                .font(StoryJuicerTypography.uiFootnoteStrong)
                .foregroundStyle(Color.sjGlassInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .sjGlassCard(
                    tint: .sjGlassSoft.opacity(0.7),
                    cornerRadius: 999
                )
                .padding(5)
        }
        .animation(StoryJuicerMotion.standard, value: isSelected)
    }
}
