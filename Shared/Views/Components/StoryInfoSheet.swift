import SwiftUI

struct StoryInfoSheet: View {
    let storyBook: StoryBook
    let originalConcept: String
    let format: BookFormat
    let illustrationStyle: IllustrationStyle
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(StoryJuicerGlassTokens.Spacing.large)

            Divider()
                .overlay(Color.sjBorder.opacity(0.45))

            ScrollView {
                VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.large) {
                    infoSection(
                        title: "Original Prompt",
                        icon: "text.quote",
                        body: originalConcept.isEmpty
                            ? "Not available — this book was saved before prompt tracking was added."
                            : originalConcept
                    )

                    infoSection(
                        title: "Moral",
                        icon: "heart.text.clipboard",
                        body: storyBook.moral
                    )

                    if !storyBook.characterDescriptions.isEmpty {
                        infoSection(
                            title: "Characters",
                            icon: "person.2",
                            body: storyBook.characterDescriptions
                        )
                    }

                    detailRow(
                        title: "Format & Style",
                        icon: "rectangle.portrait.on.rectangle.portrait",
                        value: "\(format.displayName) · \(illustrationStyle.displayName)"
                    )

                    detailRow(
                        title: "Pages",
                        icon: "book.pages",
                        value: "\(storyBook.pages.count) story pages"
                    )
                }
                .padding(StoryJuicerGlassTokens.Spacing.large)
            }
        }
        .frame(minWidth: 400, idealWidth: 480, minHeight: 360)
        .background(backgroundLayer)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Story Info")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text(storyBook.title)
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .lineLimit(1)
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

    private func infoSection(title: String, icon: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Label(title, systemImage: icon)
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            Text(body)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.subtle),
            cornerRadius: StoryJuicerGlassTokens.Radius.chip
        )
    }

    private func detailRow(title: String, icon: String, value: String) -> some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Label(title, systemImage: icon)
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            Spacer()

            Text(value)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
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
