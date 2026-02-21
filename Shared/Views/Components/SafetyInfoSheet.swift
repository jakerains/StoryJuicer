import SwiftUI

struct SafetyInfoSheet: View {
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(StoryJuicerGlassTokens.Spacing.large)

            Divider()
                .overlay(Color.sjBorder.opacity(0.45))

            ScrollView {
                VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.large) {
                    // Hero icon
                    HStack {
                        Spacer()
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.sjGold)
                        Spacer()
                    }

                    infoSection(
                        title: "Why did this happen?",
                        body: "Apple's on-device Image Playground has built-in content safety filters. These filters are important — they help keep generated images appropriate. But they can be overly cautious with creative content, sometimes flagging perfectly innocent story illustrations."
                    )

                    infoSection(
                        title: "What did StoryFox try?",
                        body: "StoryFox automatically retried with adjusted phrasing when the first attempt was declined. Most pages generate successfully after a retry or two, but sometimes the on-device model still declines a prompt despite multiple attempts."
                    )

                    infoSection(
                        title: "What can I do?",
                        body: "You have a few options:"
                    )

                    VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                        tipRow(icon: "arrow.clockwise",
                               text: "Tap Regenerate to try again — the prompt is rephrased each time, so results may differ.")
                        tipRow(icon: "slider.horizontal.3",
                               text: "Open Edit Page to rewrite the image prompt yourself with different wording.")
                        tipRow(icon: "cloud",
                               text: "Connect a free Hugging Face account in Settings. Cloud models are less restrictive with creative content and still completely free.")
                    }

                    Text("StoryFox generates everything locally by default — your stories never leave your device unless you choose a cloud provider.")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                        .italic()
                }
                .padding(StoryJuicerGlassTokens.Spacing.large)
            }
        }
        .frame(minWidth: 400, idealWidth: 460, minHeight: 380)
        .background(backgroundLayer)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("About Image Generation")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text("Why some illustrations don't generate")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .sjGlassToolbarItem(prominent: false)
        }
    }

    // MARK: - Helpers

    private func infoSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Text(title)
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            Text(body)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: icon)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StoryJuicerGlassTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.subtle),
            cornerRadius: StoryJuicerGlassTokens.Radius.chip
        )
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
