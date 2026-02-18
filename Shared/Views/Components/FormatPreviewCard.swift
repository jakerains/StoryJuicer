import SwiftUI

struct FormatPreviewCard: View {
    let format: BookFormat
    let isSelected: Bool

    var body: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.sjPaperTop.opacity(0.75),
                                Color.sjPaperBottom.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
                    }

                Image(systemName: format.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.sjCoral : Color.sjSecondaryText)
            }
            .aspectRatio(format.aspectRatio, contentMode: .fit)
            .frame(height: 62)

            Text(format.displayName)
                .font(.system(.callout, design: .rounded).weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.sjCoral : Color.sjText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
        .sjGlassChip(selected: isSelected, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.chip)
                .strokeBorder(
                    isSelected ? Color.sjCoral.opacity(0.75) : Color.sjBorder.opacity(0.45),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .animation(StoryJuicerMotion.standard, value: isSelected)
    }
}
