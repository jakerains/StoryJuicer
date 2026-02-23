import SwiftUI

struct MacBookReaderView: View {
    private enum ReaderSheet: String, Identifiable {
        case storyInfo
        case pageOverview
        case pageEdit
        case reportIssue
        case safetyInfo

        var id: String { rawValue }
    }

    @Bindable var viewModel: BookReaderViewModel
    let onExportPDF: () -> Void
    let onExportEPUB: () -> Void
    let onExportPageImage: () -> Void
    let onBackToHome: () -> Void

    @State private var activeSheet: ReaderSheet?
    @State private var pageTurnState = PageTurnState()

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                ZStack {
                    PageTurnView(
                        frontPage: pageSurface(for: pageTurnState.isTurning ? pageTurnState.fromPage : viewModel.currentPage),
                        backPage: pageSurface(for: pageTurnState.isTurning ? pageTurnState.toPage : viewModel.currentPage),
                        progress: pageTurnState.turnProgress,
                        direction: pageTurnState.turnDirection
                    )

                    navigationOverlay
                }

                pageIndicator
            }
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButton("Story Info", icon: "info.circle") {
                    activeSheet = .storyInfo
                }

                toolbarButton("Page Overview", icon: "square.grid.2x2") {
                    activeSheet = .pageOverview
                }

                toolbarButton("Edit Page", icon: "slider.horizontal.3") {
                    activeSheet = .pageEdit
                }

                Menu {
                    Button {
                        onExportPDF()
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }

                    Button {
                        onExportEPUB()
                    } label: {
                        Label("Export as EPUB", systemImage: "book")
                    }

                    Divider()

                    Button {
                        onExportPageImage()
                    } label: {
                        Label("Export Current Page as Image", systemImage: "photo")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glassProminent)
                .tint(Color.sjCoral)

                if !viewModel.missingImageIndices.isEmpty {
                    toolbarButton("Report Issue", icon: "exclamationmark.bubble", tint: .sjGold) {
                        activeSheet = .reportIssue
                    }
                }

                toolbarButton("Back to Home", icon: "house") {
                    onBackToHome()
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .storyInfo:
                StoryInfoSheet(
                    storyBook: viewModel.storyBook,
                    originalConcept: viewModel.originalConcept,
                    format: viewModel.format,
                    illustrationStyle: viewModel.illustrationStyle,
                    currentPageIndex: viewModel.currentPage,
                    textProviderName: viewModel.textProviderName,
                    imageProviderName: viewModel.imageProviderName,
                    textModelName: viewModel.textModelName,
                    imageModelName: viewModel.imageModelName,
                    conceptDecompositions: viewModel.conceptDecompositionsForPage
                ) {
                    activeSheet = nil
                }
            case .pageOverview:
                PageOverviewGrid(viewModel: viewModel) {
                    activeSheet = nil
                }
            case .pageEdit:
                PageEditSheet(viewModel: viewModel) {
                    activeSheet = nil
                }
            case .reportIssue:
                ReportIssueSheet(viewModel: viewModel) {
                    activeSheet = nil
                }
            case .safetyInfo:
                SafetyInfoSheet {
                    activeSheet = nil
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            viewModel.previousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.nextPage()
            return .handled
        }
        .onAppear {
            viewModel.onPageTurnRequested = { from, to, direction in
                pageTurnState.beginTurn(from: from, to: to, direction: direction)
            }
            pageTurnState.onTurnComplete = {
                viewModel.commitPageChange(to: pageTurnState.toPage)
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

            PaperTextureOverlay()

            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.16), .clear],
                center: .top,
                startRadius: 30,
                endRadius: 680
            )
        }
    }

    @ViewBuilder
    private func pageContent(for pageIndex: Int) -> some View {
        if viewModel.isTitlePage(at: pageIndex) {
            titlePage
        } else if viewModel.isEndPage(at: pageIndex) {
            endPage
        } else {
            contentPage(for: pageIndex)
        }
    }

    // MARK: - Book Page Card

    /// A self-contained book page card with its own paper background.
    /// This is the unit that flips during page turn animations.
    private func pageSurface(for pageIndex: Int) -> some View {
        let isCover = viewModel.isTitlePage(at: pageIndex)

        return ZStack {
            // Paper backing
            pageBackground

            // Page content — content pages handle their own padding (full-bleed images)
            pageContent(for: pageIndex)
        }
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.hero))
        // Cover gets a heavier shadow to feel like a thick hardcover book
        .shadow(color: .black.opacity(isCover ? 0.25 : 0.08), radius: isCover ? 20 : 8, y: isCover ? 8 : 4)
    }

    /// The opaque paper background for a single book page card.
    private var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            PaperTextureOverlay()
            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.16), .clear],
                center: .top,
                startRadius: 30,
                endRadius: 680
            )
        }
    }

    private var titlePage: some View {
        ZStack {
            if let coverImage = viewModel.images[0] {
                // Layer 1: Full-bleed cover illustration
                Image(decorative: coverImage, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Layer 2: Vignette — darkened edges simulate a curved hardcover surface
                RadialGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .blendMode(.multiply)

                // Layer 3: Spine strip — narrow dark gradient on the leading edge
                // simulating the bound spine where pages meet the cover
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.45), .black.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 20)
                    Spacer()
                }

                // Layer 4: Top-edge highlight — light catching the top of a hardcover
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.white.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 12)
                    Spacer()
                }

                // Layer 5: Bottom scrim — stronger gradient for title legibility
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 300)
                }

                // Layer 6–7: Title and author with embossed shadow treatment
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(viewModel.storyBook.title)
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.8), radius: 1, y: 2)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                        Text(viewModel.storyBook.authorLine)
                            .font(.system(.title3, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .italic()
                            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    }
                    .padding(.horizontal, 44)
                    .padding(.bottom, 40)
                }

                // Layer 8: Decorative gold foil border — like a hardcover book frame
                RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero - 4)
                    .strokeBorder(Color.sjGold.opacity(0.4), lineWidth: 1.5)
                    .padding(16)
            } else {
                coverPlaceholder
                    .padding(StoryJuicerGlassTokens.Spacing.large)
            }
        }
    }

    // MARK: - Storybook Page Layout

    /// Determines text box position based on text length, creating variety across pages.
    private enum StoryPageLayout {
        case bottomStrip   // < 100 chars — compact centered pill at bottom
        case bottomPanel   // 100–200 chars — wider panel spanning bottom ~25%
        case sideBox       // > 200 chars — box anchored left (even) or right (odd)

        static func layout(for text: String) -> StoryPageLayout {
            let length = text.count
            if length < 100 {
                return .bottomStrip
            } else if length <= 200 {
                return .bottomPanel
            } else {
                return .sideBox
            }
        }
    }

    /// Parchment-styled text container that floats over the full-bleed illustration.
    /// Uses solid color instead of `.ultraThinMaterial` because `PageTurnView`'s
    /// `.drawingGroup()` rasterizes to Metal, breaking material blur effects.
    private struct StoryTextBox: View {
        let text: String

        var body: some View {
            Text(text)
                .font(StoryJuicerTypography.readerBody)
                .foregroundStyle(.black)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.large)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.medium)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                        Image("PaperTexture")
                            .resizable(resizingMode: .tile)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .opacity(0.55)
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.sjBorder.opacity(0.3), lineWidth: 0.5)
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
    }

    private func contentPage(for pageIndex: Int) -> some View {
        let page = viewModel.storyPage(at: pageIndex)
        let pageImage = viewModel.image(at: pageIndex)

        return ZStack {
            if let page {
                // Full-bleed illustration
                if let pageImage {
                    Image(decorative: pageImage, scale: 1.0)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    imagePlaceholder(for: page)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Text overlay positioned based on text length
                textOverlay(for: page, at: pageIndex)
            }
        }
    }

    /// Positions the text box over the illustration based on layout template.
    @ViewBuilder
    private func textOverlay(for page: StoryPage, at pageIndex: Int) -> some View {
        let layout = StoryPageLayout.layout(for: page.text)

        switch layout {
        case .bottomStrip:
            VStack {
                Spacer()
                StoryTextBox(text: page.text)
                    .frame(maxWidth: 500)
                    .padding(.horizontal, StoryJuicerGlassTokens.Spacing.large)
                    .padding(.bottom, StoryJuicerGlassTokens.Spacing.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .bottomPanel:
            VStack {
                Spacer()
                StoryTextBox(text: page.text)
                    .frame(maxWidth: 620)
                    .padding(.horizontal, StoryJuicerGlassTokens.Spacing.large)
                    .padding(.bottom, StoryJuicerGlassTokens.Spacing.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .sideBox:
            let alignLeft = pageIndex % 2 == 0
            VStack {
                Spacer()
                HStack {
                    if !alignLeft { Spacer(minLength: StoryJuicerGlassTokens.Spacing.xLarge) }
                    StoryTextBox(text: page.text)
                        .frame(maxWidth: 420)
                    if alignLeft { Spacer(minLength: StoryJuicerGlassTokens.Spacing.xLarge) }
                }
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                .padding(.bottom, StoryJuicerGlassTokens.Spacing.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var coverPlaceholder: some View {
        let isRegenerating = viewModel.regeneratingPages.contains(0)

        return VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            if isRegenerating {
                ProgressView()
                    .controlSize(.large)
                    .tint(.sjCoral)

                Text("Regenerating cover...")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjSecondaryText)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.sjMuted)

                Text("Cover illustration not available")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)

                // Show the cover prompt so user can see what was attempted
                Text(ContentSafetyPolicy.safeCoverPrompt(
                    title: viewModel.storyBook.title,
                    concept: viewModel.storyBook.moral
                ))
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .italic()
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .textSelection(.enabled)
                .padding(.horizontal)

                // Show error if regeneration failed
                if let error = viewModel.regenerationErrors[0] {
                    Text(error)
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjCoral)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal)
                }

                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Button {
                        Task {
                            await viewModel.regenerateImage(index: 0)
                        }
                    } label: {
                        Label("Regenerate Cover", systemImage: "arrow.clockwise")
                            .font(StoryJuicerTypography.settingsControl)
                            .foregroundStyle(Color.sjCoral)
                            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                            .contentShape(Rectangle())
                            .sjGlassChip(selected: true, interactive: true)
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .safetyInfo
                    } label: {
                        Label("What happened?", systemImage: "questionmark.circle")
                            .font(StoryJuicerTypography.settingsControl)
                            .foregroundStyle(Color.sjSecondaryText)
                            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                            .contentShape(Rectangle())
                            .sjGlassChip(selected: false, interactive: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, StoryJuicerGlassTokens.Spacing.xSmall)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 430)
        .sjGlassCard(
            tint: .sjGlassWeak,
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .animation(StoryJuicerMotion.standard, value: isRegenerating)
    }

    private func imagePlaceholder(for page: StoryPage) -> some View {
        let isRegenerating = viewModel.regeneratingPages.contains(page.pageNumber)

        return VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            if isRegenerating {
                ProgressView()
                    .controlSize(.large)
                    .tint(.sjCoral)

                Text("Regenerating illustration...")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjSecondaryText)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Color.sjMuted)

                Text(page.imagePrompt)
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                // Show error if regeneration failed
                if let error = viewModel.regenerationErrors[page.pageNumber] {
                    Text(error)
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjCoral)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal)
                }

                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Button {
                        Task {
                            await viewModel.regenerateImage(index: page.pageNumber)
                        }
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(StoryJuicerTypography.settingsControl)
                            .foregroundStyle(Color.sjCoral)
                            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                            .contentShape(Rectangle())
                            .sjGlassChip(selected: true, interactive: true)
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .safetyInfo
                    } label: {
                        Label("What happened?", systemImage: "questionmark.circle")
                            .font(StoryJuicerTypography.settingsControl)
                            .foregroundStyle(Color.sjSecondaryText)
                            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                            .contentShape(Rectangle())
                            .sjGlassChip(selected: false, interactive: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, StoryJuicerGlassTokens.Spacing.xSmall)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .sjGlassCard(
            tint: .sjGlassWeak,
            cornerRadius: StoryJuicerGlassTokens.Radius.card
        )
        .animation(StoryJuicerMotion.standard, value: isRegenerating)
    }

    private var endPage: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(Color.sjGold)

            Text("The End")
                .font(.system(size: 46, weight: .bold, design: .serif))
                .foregroundStyle(Color.sjGlassInk)

            Text(viewModel.storyBook.moral)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.sjSecondaryText)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 70)

            storyFoxStamp

            Spacer(minLength: 0)
        }
        .padding(StoryJuicerGlassTokens.Spacing.large)
    }

    private var storyFoxStamp: some View {
        Image("StoryFoxStamp")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: 100, height: 100)
            .opacity(0.7)
            .padding(.top, StoryJuicerGlassTokens.Spacing.medium)
    }

    private var navigationOverlay: some View {
        HStack {
            pageNavButton(
                systemImage: "chevron.left",
                disabled: viewModel.isFirstPage || pageTurnState.isTurning,
                action: { viewModel.previousPage() }
            )

            Spacer()

            pageNavButton(
                systemImage: "chevron.right",
                disabled: viewModel.isLastPage || pageTurnState.isTurning,
                action: { viewModel.nextPage() }
            )
        }
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small)
    }

    private func pageNavButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
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

    /// Toolbar button that bypasses macOS toolbar button styling by using `.plain`
    /// and applying a manual glass capsule, matching the Export menu's appearance.
    private func toolbarButton(
        _ title: String,
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(tint ?? Color.primary)
                .frame(width: 28, height: 28)
                .contentShape(Capsule())
                .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var pageIndicator: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Button {
                    viewModel.goToPage(index)
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
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.large)
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
