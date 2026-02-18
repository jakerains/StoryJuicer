import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.sjCoral)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Text("Needs a quick tweak")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text(message)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
                    .lineLimit(4)
            }

            Spacer(minLength: StoryJuicerGlassTokens.Spacing.small)

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button("Retry") {
                    onRetry()
                }
                .sjGlassToolbarItem(prominent: true)
                .tint(Color.sjCoral)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(StoryJuicerTypography.uiFootnoteStrong)
                        .frame(width: 24, height: 24)
                }
                .sjGlassToolbarItem(prominent: false)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(tint: .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.card)
                .strokeBorder(Color.sjCoral.opacity(0.45), lineWidth: 1)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
