import SwiftUI
import CoreGraphics

struct PageOverviewGrid: View {
    @Bindable var viewModel: BookReaderViewModel
    var dismiss: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 130, maximum: 170), spacing: StoryJuicerGlassTokens.Spacing.medium)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(StoryJuicerGlassTokens.Spacing.large)

            Divider()
                .overlay(Color.sjBorder.opacity(0.45))

            ScrollView {
                GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                    LazyVGrid(columns: columns, spacing: StoryJuicerGlassTokens.Spacing.medium) {
                        thumbnailCell(index: 0, label: "Cover")

                        ForEach(viewModel.storyBook.pages, id: \.pageNumber) { page in
                            thumbnailCell(index: page.pageNumber, label: "Page \(page.pageNumber)")
                        }
                    }
                    .padding(StoryJuicerGlassTokens.Spacing.large)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 380)
        .background(backgroundLayer)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Page Overview")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text("\(viewModel.storyBook.pages.count + 1) illustrations")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)

                if let lastError = viewModel.lastRegenerationError {
                    Text(lastError)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.sjCoral)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !viewModel.missingImageIndices.isEmpty {
                Button {
                    viewModel.regenerateAllMissing()
                } label: {
                    Label("Regenerate Missing", systemImage: "arrow.clockwise")
                        .font(StoryJuicerTypography.uiMetaStrong)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.sjCoral)
                .controlSize(.small)
            }

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .sjGlassToolbarItem(prominent: false)
        }
    }

    private func thumbnailCell(index: Int, label: String) -> some View {
        let isCurrentPage = currentReaderPage(for: index) == viewModel.currentPage
        let hasImage = viewModel.images[index] != nil

        return VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            if hasImage {
                Button {
                    withAnimation(StoryJuicerMotion.emphasis) {
                        viewModel.goToPage(currentReaderPage(for: index))
                    }
                    dismiss()
                } label: {
                    PageThumbnail(
                        pageNumber: index,
                        image: viewModel.images[index],
                        isGenerating: viewModel.regeneratingPages.contains(index),
                        isSelected: isCurrentPage,
                        onRegenerate: nil
                    )
                }
                .buttonStyle(.plain)
            } else {
                PageThumbnail(
                    pageNumber: index,
                    image: viewModel.images[index],
                    isGenerating: viewModel.regeneratingPages.contains(index),
                    isSelected: isCurrentPage,
                    onRegenerate: {
                        Task { await viewModel.regeneratePage(index: index) }
                    }
                )
            }

            Text(label)
                .font(.system(.callout, design: .rounded).weight(.medium))
                .foregroundStyle(Color.sjSecondaryText)
                .padding(.horizontal, 2)
        }
    }

    /// Reader pages: 0 = title, 1...N = story pages, N+1 = "The End".
    /// Image indices: 0 = cover, pageNumber = story page.
    private func currentReaderPage(for imageIndex: Int) -> Int {
        if imageIndex == 0 { return 0 }
        return imageIndex
    }
}
