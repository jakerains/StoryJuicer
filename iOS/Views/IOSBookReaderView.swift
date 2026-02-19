import SwiftUI

struct IOSBookReaderView: View {
    private enum ReaderSheet: String, Identifiable {
        case pageOverview

        var id: String { rawValue }
    }

    @Bindable var viewModel: BookReaderViewModel
    let pdfRenderer: StoryPDFRenderer
    let epubRenderer: StoryEPUBRenderer
    let onBackToHome: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var activeSheet: ReaderSheet?
    @State private var dragOffset: CGFloat = 0

    private var textPadding: CGFloat {
        sizeClass == .compact ? 24 : 60
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                ZStack {
                    pageContent
                        .id(viewModel.currentPage)
                        .transition(.push(from: viewModel.currentPage > 0 ? .trailing : .leading))
                        .animation(StoryJuicerMotion.emphasis, value: viewModel.currentPage)

                    navigationOverlay
                }
                .gesture(swipeGesture)

                pageIndicator
            }
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    activeSheet = .pageOverview
                } label: {
                    Label("Page Overview", systemImage: "square.grid.2x2")
                }
                .sjGlassToolbarItem(prominent: false)

                Menu {
                    ShareLink(
                        item: IOSExportView.renderPDFToFile(
                            storybook: viewModel.storyBook,
                            images: viewModel.images,
                            format: viewModel.format,
                            renderer: pdfRenderer
                        ),
                        preview: SharePreview(
                            viewModel.storyBook.title,
                            image: Image(systemName: "doc.richtext")
                        )
                    ) {
                        Label("Share as PDF", systemImage: "doc.richtext")
                    }

                    ShareLink(
                        item: IOSExportView.renderEPUBToFile(
                            storybook: viewModel.storyBook,
                            images: viewModel.images,
                            format: viewModel.format,
                            renderer: epubRenderer
                        ),
                        preview: SharePreview(
                            viewModel.storyBook.title,
                            image: Image(systemName: "book")
                        )
                    ) {
                        Label("Share as EPUB", systemImage: "book")
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .sjGlassToolbarItem(prominent: true)
                .tint(Color.sjCoral)

                Button {
                    onBackToHome()
                } label: {
                    Label("Back to Home", systemImage: "house")
                }
                .sjGlassToolbarItem(prominent: false)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .pageOverview:
                PageOverviewGrid(viewModel: viewModel) {
                    activeSheet = nil
                }
            }
        }
        .onKeyPress(.leftArrow) {
            withAnimation(StoryJuicerMotion.emphasis) {
                viewModel.previousPage()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            withAnimation(StoryJuicerMotion.emphasis) {
                viewModel.nextPage()
            }
            return .handled
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal < -50 && !viewModel.isLastPage {
                    withAnimation(StoryJuicerMotion.emphasis) {
                        viewModel.nextPage()
                    }
                } else if horizontal > 50 && !viewModel.isFirstPage {
                    withAnimation(StoryJuicerMotion.emphasis) {
                        viewModel.previousPage()
                    }
                }
            }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.16), .clear],
                center: .top,
                startRadius: 30,
                endRadius: 680
            )
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if viewModel.isTitlePage {
            titlePage
        } else if viewModel.isEndPage {
            endPage
        } else {
            contentPage
        }
    }

    private var titlePage: some View {
        ScrollView {
            VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
                if let coverImage = viewModel.images[0] {
                    Image(decorative: coverImage, scale: 1.0)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.hero))
                        .shadow(color: StoryJuicerGlassTokens.Shadow.color, radius: 18, y: 10)
                        .frame(maxHeight: sizeClass == .compact ? 300 : 430)
                }

                VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Text(viewModel.storyBook.title)
                        .font(StoryJuicerTypography.readerTitle)
                        .foregroundStyle(Color.sjGlassInk)
                        .multilineTextAlignment(.center)

                    Text(viewModel.storyBook.authorLine)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.sjSecondaryText)
                        .italic()
                }
                .padding(StoryJuicerGlassTokens.Spacing.large)
                .frame(maxWidth: 700)
                .sjGlassCard(
                    tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
                    cornerRadius: StoryJuicerGlassTokens.Radius.hero
                )
            }
            .padding(StoryJuicerGlassTokens.Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentPage: some View {
        ScrollView {
            VStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                if let page = viewModel.currentStoryPage {
                    Group {
                        if let image = viewModel.currentImage {
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.card))
                                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                        } else {
                            VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.sjMuted)

                                Text(page.imagePrompt)
                                    .font(StoryJuicerTypography.uiMeta)
                                    .foregroundStyle(Color.sjSecondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .sjGlassCard(
                                tint: .sjGlassWeak,
                                cornerRadius: StoryJuicerGlassTokens.Radius.card
                            )
                        }
                    }
                    .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                    .padding(.top, StoryJuicerGlassTokens.Spacing.medium)

                    Text(page.text)
                        .font(StoryJuicerTypography.readerBody)
                        .foregroundStyle(Color.sjText)
                        .lineSpacing(10)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, textPadding)
                        .padding(.vertical, StoryJuicerGlassTokens.Spacing.large)
                        .frame(maxWidth: .infinity)
                        .sjGlassCard(
                            tint: .sjReadableCard.opacity(StoryJuicerGlassTokens.Tint.standard),
                            cornerRadius: StoryJuicerGlassTokens.Radius.card
                        )
                        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                        .padding(.bottom, StoryJuicerGlassTokens.Spacing.medium)
                }
            }
        }
    }

    private var endPage: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(Color.sjGold)

            Text("The End")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(Color.sjGlassInk)

            Text(viewModel.storyBook.moral)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.sjSecondaryText)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, textPadding)
        }
        .padding(StoryJuicerGlassTokens.Spacing.xLarge)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .frame(maxWidth: 780, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navigationOverlay: some View {
        HStack {
            pageNavButton(
                systemImage: "chevron.left",
                disabled: viewModel.isFirstPage,
                action: { viewModel.previousPage() }
            )

            Spacer()

            pageNavButton(
                systemImage: "chevron.right",
                disabled: viewModel.isLastPage,
                action: { viewModel.nextPage() }
            )
        }
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small)
    }

    private func pageNavButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(StoryJuicerMotion.emphasis) {
                action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 46, height: 46)
                .sjGlassCard(
                    tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
                    interactive: true,
                    cornerRadius: 999
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.001 : 1)
        .animation(StoryJuicerMotion.fast, value: disabled)
    }

    private var pageIndicator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                ForEach(0..<viewModel.totalPages, id: \.self) { index in
                    Button {
                        withAnimation(StoryJuicerMotion.emphasis) {
                            viewModel.goToPage(index)
                        }
                    } label: {
                        Capsule()
                            .fill(index == viewModel.currentPage ? Color.sjCoral : Color.sjBorder)
                            .frame(width: index == viewModel.currentPage ? 18 : 7, height: 7)
                            .animation(StoryJuicerMotion.standard, value: viewModel.currentPage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pageIndicatorAccessibilityLabel(index))
                }
            }
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
        }
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.subtle),
            cornerRadius: 999
        )
        .padding(.bottom, StoryJuicerGlassTokens.Spacing.small)
    }

    private func pageIndicatorAccessibilityLabel(_ index: Int) -> String {
        if index == 0 {
            return "Go to title page"
        }
        if index == viewModel.totalPages - 1 {
            return "Go to ending page"
        }
        return "Go to page \(index)"
    }
}
