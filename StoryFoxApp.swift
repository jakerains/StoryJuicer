import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct StoryFoxApp: App {
#if os(macOS)
    @State private var updateManager = SoftwareUpdateManager()
#endif

    var body: some Scene {
        WindowGroup {
            MainView()
        }
#if os(macOS)
        .defaultSize(width: 1080, height: 760)
#endif
        .modelContainer(for: StoredStorybook.self)

#if os(macOS)
        Settings {
            MacSettingsView(updateManager: updateManager)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About StoryFox") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: aboutPanelOptions)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateManager.checkForUpdates()
                }
                .disabled(!updateManager.canCheckForUpdates)
            }
#if DEBUG
            CommandGroup(after: .windowArrangement) {
                Button("Test Character Harness") {
                    openTestHarnessWindow()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
#endif
        }
#endif
    }

#if os(macOS)
#if DEBUG
    private func openTestHarnessWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Consistency Test Harness"
        window.center()
        window.contentView = NSHostingView(rootView: MacTestHarnessView())
        window.makeKeyAndOrderFront(nil)
        // Prevent window from being deallocated by retaining it
        window.isReleasedWhenClosed = false
    }
#endif

    private var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] {
        let credits = NSMutableAttributedString()

        let bodyFont = NSFont.systemFont(ofSize: 11, weight: .regular)
        let bodyColor = NSColor.secondaryLabelColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 4

        // Line 1: "Made with [heart]"
        let madeWith = NSAttributedString(
            string: "Made with \u{2764}\u{FE0F}\n",
            attributes: [
                .font: bodyFont,
                .foregroundColor: bodyColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        credits.append(madeWith)

        // Line 2: "by"
        let byLine = NSAttributedString(
            string: "by\n",
            attributes: [
                .font: bodyFont,
                .foregroundColor: bodyColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        credits.append(byLine)

        // Line 3: "Jake Rains" as a clickable link
        let linkFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let jakeRains = NSAttributedString(
            string: "Jake Rains",
            attributes: [
                .font: linkFont,
                .foregroundColor: NSColor.linkColor,
                .link: URL(string: "https://jakerains.com")!,
                .paragraphStyle: paragraphStyle
            ]
        )
        credits.append(jakeRains)

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: credits
        ]

        // Hero illustration in the About panel
        if let heroImage = NSImage(named: "StoryFoxHero"),
           let bestRep = heroImage.bestRepresentation(for: NSRect(origin: .zero, size: heroImage.size), context: nil, hints: nil) {
            let pixelW = CGFloat(bestRep.pixelsWide)
            let pixelH = CGFloat(bestRep.pixelsHigh)
            let aspect = pixelH / pixelW
            let targetWidth: CGFloat = 200
            let size = NSSize(width: targetWidth, height: targetWidth * aspect)
            let resized = NSImage(size: size)
            resized.lockFocus()
            heroImage.draw(in: NSRect(origin: .zero, size: size),
                           from: NSRect(origin: .zero, size: heroImage.size),
                           operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            options[.applicationIcon] = resized
        }

        return options
    }
#endif
}

// MARK: - Navigation

enum AppRoute: Hashable {
    case creation
    case generating
    case reading
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StoredStorybook> { $0.isFavorite == true },
           sort: \StoredStorybook.displayOrder) private var favoriteBooks: [StoredStorybook]
    @Query(filter: #Predicate<StoredStorybook> { $0.isFavorite == false },
           sort: \StoredStorybook.displayOrder) private var regularBooks: [StoredStorybook]

    private var allBooks: [StoredStorybook] { favoriteBooks + regularBooks }

    @State private var viewModel = CreationViewModel()
    @State private var route: AppRoute = .creation
    @State private var readerViewModel: BookReaderViewModel?
    @State private var pdfRenderer = StoryPDFRenderer()
    @State private var epubRenderer = StoryEPUBRenderer()
    @State private var selectedSavedBookID: UUID?
    @AppStorage("sidebar.favoritesExpanded") private var isFavoritesExpanded = true
    @AppStorage("sidebar.storybooksExpanded") private var isStorybooksExpanded = true
#if os(iOS)
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase
#endif

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .background(detailBackground)
        }
        .tint(.sjCoral)
        .navigationSplitViewStyle(.balanced)
#if os(macOS)
        .frame(minWidth: 860, minHeight: 580)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            try? modelContext.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            try? modelContext.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            consumePendingShortcutRequest()
        }
#endif
#if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                try? modelContext.save()
            }
            if newPhase == .active {
                consumePendingShortcutRequest()
            }
        }
        .sheet(isPresented: $showingSettings) {
            IOSModelSettingsView()
        }
#endif
        .onAppear {
            consumePendingShortcutRequest()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSavedBookID) {
                Button {
                    selectedSavedBookID = nil
                    viewModel.reset()
                    readerViewModel = nil
                    route = .creation
                } label: {
                    HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.sjCoral)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Story")
                                .font(StoryJuicerTypography.uiTitle)
                                .foregroundStyle(Color.sjGlassInk)
                            Text("Start from a fresh concept")
                                .font(StoryJuicerTypography.uiMeta)
                                .foregroundStyle(Color.sjSecondaryText)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small)
                    .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                    .contentShape(Rectangle())
                    .sjGlassCard(
                        tint: .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard),
                        interactive: true,
                        cornerRadius: StoryJuicerGlassTokens.Radius.card
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 2)

                if !favoriteBooks.isEmpty {
                    Section(isExpanded: $isFavoritesExpanded) {
                        ForEach(favoriteBooks) { book in
                            savedBookRow(
                                book,
                                isSelected: selectedSavedBookID == book.id
                            )
                            .tag(book.id)
                            .listRowBackground(sidebarRowBackground)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(book)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation(StoryJuicerMotion.standard) {
                                        book.isFavorite = false
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label("Unfavorite", systemImage: "star.slash")
                                }
                                .tint(.sjGold)
                            }
                        }
                        .onDelete(perform: deleteFavoriteBooks)
                        .onMove(perform: moveFavorites)
                    } header: {
                        sidebarSectionHeader(
                            title: "Favorites",
                            systemImage: "star.fill",
                            count: favoriteBooks.count,
                            tint: .sjGold
                        )
                    }
                }

                if !regularBooks.isEmpty {
                    Section(isExpanded: $isStorybooksExpanded) {
                        ForEach(regularBooks) { book in
                            savedBookRow(
                                book,
                                isSelected: selectedSavedBookID == book.id
                            )
                            .tag(book.id)
                            .listRowBackground(sidebarRowBackground)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(book)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation(StoryJuicerMotion.standard) {
                                        book.isFavorite = true
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label("Favorite", systemImage: "star.fill")
                                }
                                .tint(.sjGold)
                            }
                        }
                        .onDelete(perform: deleteRegularBooks)
                        .onMove(perform: moveRegularBooks)
                    } header: {
                        sidebarSectionHeader(
                            title: "Your Storybooks",
                            systemImage: "books.vertical",
                            count: regularBooks.count,
                            tint: .sjSecondaryText
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
            .tint(.sjCoral)
            .accentColor(.sjCoral)
            .background(sidebarBackground)
            .onChange(of: selectedSavedBookID) { _, newID in
                if let id = newID, let book = allBooks.first(where: { $0.id == id }) {
                    openSavedBook(book)
                }
            }
        }
        .background(sidebarBackground)
    }

    private var sidebarHeader: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            sidebarBrandIcon
                .frame(width: 32, height: 32)
                .clipShape(.rect(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)

            Text("StoryFox")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

            Spacer()

#if os(iOS)
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Color.sjCoral)
            }
            .buttonStyle(.plain)
#endif
        }
    }

    @ViewBuilder
    private var sidebarBrandIcon: some View {
#if os(macOS)
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFill()
        } else {
            fallbackSidebarSymbol
        }
#else
        if let uiImage = UIImage(named: "AppIcon") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            fallbackSidebarSymbol
        }
#endif
    }

    private var fallbackSidebarSymbol: some View {
        Image(systemName: "book.closed.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.sjCoral)
            .frame(width: 32, height: 32)
            .sjGlassCard(
                tint: .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard),
                cornerRadius: 999
            )
    }

    private func savedBookRow(_ book: StoredStorybook, isSelected: Bool) -> some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: "text.book.closed.fill")
                .foregroundStyle(isSelected ? Color.sjCoral : Color.sjSecondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)
                    .lineLimit(2)

                Text(book.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(StoryJuicerMotion.standard) {
                    book.isFavorite.toggle()
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: book.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(book.isFavorite ? Color.sjGold : Color.sjMuted.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small)
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
        .sjGlassCard(
            tint: isSelected
                ? .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard)
                : .sjGlassWeak,
            cornerRadius: StoryJuicerGlassTokens.Radius.chip
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.chip)
                .strokeBorder(
                    isSelected ? Color.sjCoral.opacity(0.7) : Color.clear,
                    lineWidth: 1
                )
        }
        .contextMenu {
            Button {
                withAnimation(StoryJuicerMotion.standard) {
                    book.isFavorite.toggle()
                    try? modelContext.save()
                }
            } label: {
                Label(
                    book.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: book.isFavorite ? "star.slash" : "star.fill"
                )
            }

            Divider()

            Button(role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func sidebarSectionHeader(title: String, systemImage: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.caption)

            Text(title)
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(Color.sjSecondaryText)

            Text("\(count)")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjMuted)
        }
        .textCase(nil)
    }

    private var sidebarRowBackground: some View {
        // Opaque background that covers the system blue selection highlight
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var detailBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PaperTextureOverlay()
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch route {
        case .creation:
            creationView
                .onChange(of: viewModel.phase) { _, newPhase in
                    handlePhaseChange(newPhase)
                }

        case .generating:
            generatingView
                .onChange(of: viewModel.phase) { _, newPhase in
                    handlePhaseChange(newPhase)
                }

        case .reading:
            if let readerVM = readerViewModel {
                readerView(readerVM)
            }
        }
    }

    @ViewBuilder
    private var creationView: some View {
#if os(macOS)
        MacCreationView(viewModel: viewModel)
#else
        IOSCreationView(viewModel: viewModel)
#endif
    }

    @ViewBuilder
    private var generatingView: some View {
#if os(macOS)
        MacGenerationProgressView(viewModel: viewModel) {
            viewModel.cancel()
            route = .creation
        }
#else
        IOSGenerationProgressView(viewModel: viewModel) {
            viewModel.cancel()
            route = .creation
        }
#endif
    }

    @ViewBuilder
    private func readerView(_ readerVM: BookReaderViewModel) -> some View {
#if os(macOS)
        MacBookReaderView(
            viewModel: readerVM,
            onExportPDF: {
                MacExportView.exportPDF(
                    storybook: readerVM.storyBook,
                    images: readerVM.images,
                    format: readerVM.format,
                    renderer: pdfRenderer
                )
            },
            onExportEPUB: {
                MacExportView.exportEPUB(
                    storybook: readerVM.storyBook,
                    images: readerVM.images,
                    format: readerVM.format,
                    renderer: epubRenderer
                )
            },
            onBackToHome: {
                viewModel.reset()
                readerViewModel = nil
                route = .creation
            }
        )
#else
        IOSBookReaderView(
            viewModel: readerVM,
            pdfRenderer: pdfRenderer,
            epubRenderer: epubRenderer,
            onBackToHome: {
                viewModel.reset()
                readerViewModel = nil
                route = .creation
            }
        )
#endif
    }

    // MARK: - Actions

    private func handlePhaseChange(_ phase: GenerationPhase) {
        switch phase {
        case .generatingText, .generatingImages:
            if route != .generating {
                route = .generating
            }
        case .complete:
            if let book = viewModel.storyBook {
                let readerVM = BookReaderViewModel(
                    storyBook: book,
                    images: viewModel.generatedImages,
                    format: viewModel.selectedFormat,
                    style: viewModel.selectedStyle,
                    generator: viewModel.illustrationGenerator
                )
                readerVM.parsedCharacters = viewModel.parsedCharacters
                readerVM.onImageRegenerated = { [weak readerVM] index, cgImage in
                    guard let readerVM else { return }
                    persistRegeneratedImage(index: index, image: cgImage, bookID: readerVM.storedBookID)
                }
                readerVM.onTextEdited = { [weak readerVM] updatedBook in
                    guard let readerVM else { return }
                    persistEditedText(book: updatedBook, bookID: readerVM.storedBookID)
                }
                readerViewModel = readerVM
                route = .reading
                saveBook(book)
            }
        case .failed:
            route = .creation
        case .idle:
            break
        }
    }

    private func saveBook(_ book: StoryBook) {
        // Shift existing regular books down so the new one appears at top
        for existing in regularBooks {
            existing.displayOrder += 1
        }

        let stored = StoredStorybook.from(
            storyBook: book,
            images: viewModel.generatedImages,
            format: viewModel.selectedFormat,
            style: viewModel.selectedStyle
        )
        stored.displayOrder = 0
        modelContext.insert(stored)
        readerViewModel?.storedBookID = stored.id
        try? modelContext.save()
    }

    private func openSavedBook(_ stored: StoredStorybook) {
        let book = stored.toStoryBook()
        let images = stored.toImages()
        let readerVM = BookReaderViewModel(
            storyBook: book,
            images: images,
            format: stored.format,
            style: stored.style,
            generator: IllustrationGenerator()
        )
        readerVM.storedBookID = stored.id
        readerVM.onImageRegenerated = { [weak readerVM] index, cgImage in
            guard let readerVM else { return }
            persistRegeneratedImage(index: index, image: cgImage, bookID: readerVM.storedBookID)
        }
        readerVM.onTextEdited = { [weak readerVM] updatedBook in
            guard let readerVM else { return }
            persistEditedText(book: updatedBook, bookID: readerVM.storedBookID)
        }
        readerViewModel = readerVM
        route = .reading
    }

    private func persistRegeneratedImage(index: Int, image: CGImage, bookID: UUID?) {
        guard let bookID,
              let stored = allBooks.first(where: { $0.id == bookID }) else { return }

        let pngData = cgImageToPNGData(image)

        if index == 0 {
            stored.coverImageData = pngData
        } else if let storedPage = stored.pages.first(where: { $0.pageNumber == index }) {
            storedPage.imageData = pngData
        }

        try? modelContext.save()
    }

    private func persistEditedText(book: StoryBook, bookID: UUID?) {
        guard let bookID,
              let stored = allBooks.first(where: { $0.id == bookID }) else { return }

        stored.title = book.title
        stored.authorLine = book.authorLine
        stored.moral = book.moral

        for page in book.pages {
            if let storedPage = stored.pages.first(where: { $0.pageNumber == page.pageNumber }) {
                storedPage.text = page.text
                storedPage.imagePrompt = page.imagePrompt
            }
        }

        try? modelContext.save()
    }

    private func deleteFavoriteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(favoriteBooks[index])
        }
        try? modelContext.save()
    }

    private func deleteRegularBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(regularBooks[index])
        }
        try? modelContext.save()
    }

    private func moveFavorites(from source: IndexSet, to destination: Int) {
        var books = Array(favoriteBooks)
        books.move(fromOffsets: source, toOffset: destination)
        for (index, book) in books.enumerated() {
            book.displayOrder = index
        }
        try? modelContext.save()
    }

    private func moveRegularBooks(from source: IndexSet, to destination: Int) {
        var books = Array(regularBooks)
        books.move(fromOffsets: source, toOffset: destination)
        for (index, book) in books.enumerated() {
            book.displayOrder = index
        }
        try? modelContext.save()
    }

    private func consumePendingShortcutRequest() {
        guard let request = ShortcutStoryRequestStore.consume() else { return }

        selectedSavedBookID = nil
        readerViewModel = nil
        route = .creation
        viewModel.reset()

        viewModel.storyConcept = request.concept
        viewModel.pageCount = request.pageCount
        viewModel.selectedFormat = request.format
        viewModel.selectedStyle = request.style

        if request.autoStart {
            viewModel.squeezeStory()
        }
    }
}
