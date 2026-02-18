import SwiftUI

struct UnavailableOverlay: View {
    let reason: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .ignoresSafeArea()

            VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
                header

                Text(reason)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.sjSecondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                Divider()
                    .overlay(Color.sjBorder)
                    .frame(width: 220)

                VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                    requirementRow(icon: "cpu", text: "Apple Silicon Mac (M1 or later)")
                    requirementRow(icon: "gear", text: "macOS 26 (Tahoe) or later")
                    requirementRow(icon: "brain", text: "Apple Intelligence enabled in System Settings")
                    requirementRow(icon: "arrow.down.circle", text: "On-device models downloaded")
                }
            }
            .padding(40)
            .sjGlassCard(
                tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.emphasis),
                cornerRadius: StoryJuicerGlassTokens.Radius.hero
            )
            .overlay {
                RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                    .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
            }
            .frame(maxWidth: 600)
            .padding(24)
        }
    }

    private var header: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: "exclamationmark.brain")
                .font(.system(size: 56))
                .foregroundStyle(Color.sjCoral)
                .symbolEffect(.pulse, options: .repeating)

            Text("Apple Intelligence Required")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.sjGlassInk)
        }
    }

    private func requirementRow(icon: String, text: String) -> some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.sjCoral)
            Text(text)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjText)
        }
    }
}
