import SwiftUI

struct StoryInfoSheet: View {
    let storyBook: StoryBook
    let originalConcept: String
    let format: BookFormat
    let illustrationStyle: IllustrationStyle
    let currentPageIndex: Int
    let textProviderName: String
    let imageProviderName: String
    let textModelName: String
    let imageModelName: String
    var dismiss: () -> Void

    /// The story page for the current position, if it's a content page (not title or end).
    private var currentStoryPage: StoryPage? {
        let totalPages = storyBook.pages.count + 2
        guard currentPageIndex > 0, currentPageIndex < totalPages - 1 else { return nil }
        let pageIndex = currentPageIndex - 1
        guard pageIndex >= 0, pageIndex < storyBook.pages.count else { return nil }
        return storyBook.pages[pageIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(StoryJuicerGlassTokens.Spacing.large)

            Divider()
                .overlay(Color.sjBorder.opacity(0.45))

            ScrollView {
                VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.large) {
                    // Current page image prompt (contextual — only on content pages)
                    if let page = currentStoryPage {
                        infoSection(
                            title: "Page \(page.pageNumber) Image Prompt",
                            icon: "paintbrush",
                            body: page.imagePrompt
                        )
                    }

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

                    // Generation info
                    if !textProviderName.isEmpty || !imageProviderName.isEmpty {
                        generationSection
                    }
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

    // MARK: - Generation Info

    private var generationSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Label("Generation", systemImage: "cpu")
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            VStack(alignment: .leading, spacing: 6) {
                if !textProviderName.isEmpty {
                    generationRow(
                        label: "Text",
                        provider: textProviderName,
                        model: textModelName
                    )
                }

                if !imageProviderName.isEmpty {
                    generationRow(
                        label: "Images",
                        provider: imageProviderName,
                        model: imageModelName
                    )
                }
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.subtle),
            cornerRadius: StoryJuicerGlassTokens.Radius.chip
        )
    }

    private func generationRow(label: String, provider: String, model: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .frame(width: 50, alignment: .leading)

            if !model.isEmpty && model != provider {
                Text("\(provider) · \(model)")
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
                    .textSelection(.enabled)
            } else {
                Text(provider)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
                    .textSelection(.enabled)
            }
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
