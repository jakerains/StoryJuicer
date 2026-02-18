import SwiftUI
import SwiftData

@main
struct StoryJuicerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .defaultSize(width: 1080, height: 760)
        .modelContainer(for: StoredStorybook.self)
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
    @State private var pdfRenderer = MacPDFRenderer()
    @State private var selectedSavedBookID: UUID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .background(detailBackground)
        }
        .navigationSplitViewStyle(.balanced)
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
            Image(systemName: "book.closed.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 32, height: 32)
                .sjGlassCard(
                    tint: .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard),
                    cornerRadius: 999
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("StoryJuicer")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)
                Text("Editorial Warm Glass")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
            }

            Spacer()
        }
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
            MacCreationView(viewModel: viewModel)
                .onChange(of: viewModel.phase) { _, newPhase in
                    handlePhaseChange(newPhase)
                }

        case .generating:
            MacGenerationProgressView(viewModel: viewModel) {
                viewModel.cancel()
                route = .creation
            }
            .onChange(of: viewModel.phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }

        case .reading:
            if let readerVM = readerViewModel {
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
                    onBackToHome: {
                        viewModel.reset()
                        readerViewModel = nil
                        route = .creation
                    }
                )
            }
        }
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
