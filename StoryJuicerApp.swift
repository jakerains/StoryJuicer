import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct StoryJuicerApp: App {
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
            MacModelSettingsView(updateManager: updateManager)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateManager.checkForUpdates()
                }
                .disabled(!updateManager.canCheckForUpdates)
            }
        }
#endif
    }
}

// MARK: - Navigation

enum AppRoute: Hashable {
    case creation
    case generating
    case reading
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredStorybook.createdAt, order: .reverse) private var savedBooks: [StoredStorybook]

    @State private var viewModel = CreationViewModel()
    @State private var route: AppRoute = .creation
    @State private var readerViewModel: BookReaderViewModel?
    @State private var pdfRenderer = StoryPDFRenderer()
    @State private var epubRenderer = StoryEPUBRenderer()
    @State private var selectedSavedBookID: UUID?
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
            sidebarHeader
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                .padding(.top, StoryJuicerGlassTokens.Spacing.medium)
                .padding(.bottom, StoryJuicerGlassTokens.Spacing.small)

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

                if !savedBooks.isEmpty {
                    Section {
                        ForEach(savedBooks) { book in
                            savedBookRow(
                                book,
                                isSelected: selectedSavedBookID == book.id
                            )
                            .tag(book.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteBooks)
                    } header: {
                        Text("Your Storybooks")
                            .font(StoryJuicerTypography.uiMetaStrong)
                            .foregroundStyle(Color.sjSecondaryText)
                            .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
            .background(sidebarBackground)
            .onChange(of: selectedSavedBookID) { _, newID in
                if let id = newID, let book = savedBooks.first(where: { $0.id == id }) {
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

            Text("StoryJuicer")
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
            Button(role: .destructive) {
                modelContext.delete(book)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                readerVM.onImageRegenerated = { [weak readerVM] index, cgImage in
                    guard let readerVM else { return }
                    persistRegeneratedImage(index: index, image: cgImage, bookID: readerVM.storedBookID)
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
        let stored = StoredStorybook.from(
            storyBook: book,
            images: viewModel.generatedImages,
            format: viewModel.selectedFormat,
            style: viewModel.selectedStyle
        )
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
        readerViewModel = readerVM
        route = .reading
    }

    private func persistRegeneratedImage(index: Int, image: CGImage, bookID: UUID?) {
        guard let bookID,
              let stored = savedBooks.first(where: { $0.id == bookID }) else { return }

        let pngData = cgImageToPNGData(image)

        if index == 0 {
            stored.coverImageData = pngData
        } else if let storedPage = stored.pages.first(where: { $0.pageNumber == index }) {
            storedPage.imageData = pngData
        }

        try? modelContext.save()
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedBooks[index])
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
