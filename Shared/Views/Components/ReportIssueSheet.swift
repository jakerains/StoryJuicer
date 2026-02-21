import SwiftUI
import CoreGraphics

struct ReportIssueSheet: View {
    let viewModel: BookReaderViewModel
    var dismiss: () -> Void

    @State private var userNotes: String = ""
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case submitting
        case success
        case error(String)
    }

    private var missingCount: Int { viewModel.missingImageIndices.count }
    private var totalImageCount: Int { viewModel.allImageIndices.count }
    private var successfulCount: Int { totalImageCount - missingCount }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(StoryJuicerGlassTokens.Spacing.large)

            Divider()
                .overlay(Color.sjBorder.opacity(0.45))

            ScrollView {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
                    switch phase {
                    case .idle, .submitting, .error:
                        reportContent
                    case .success:
                        successContent
                    }
                }
                .padding(StoryJuicerGlassTokens.Spacing.large)
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(backgroundLayer)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Report Missing Images")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text("Help us improve image generation")
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

    // MARK: - Report Content

    private var reportContent: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            // Summary card — what will be sent
            summaryCard

            // Optional notes
            notesSection

            // Privacy note
            Text("This report is voluntary and contains only the data shown above.")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Error message
            if case .error(let message) = phase {
                Text(message)
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjCoral)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            // Submit button
            Button {
                Task { await submitReport() }
            } label: {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    if phase == .submitting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(phase == .submitting ? "Submitting..." : "Submit Report")
                        .font(StoryJuicerTypography.uiBodyStrong)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.sjCoral)
            .disabled(phase == .submitting)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text("What will be sent")
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(Color.sjGlassInk)

            summaryRow(icon: "book.closed", label: "Story title", value: viewModel.storyBook.title)
            summaryRow(icon: "photo.badge.exclamationmark",
                       label: "Missing images",
                       value: "\(missingCount) of \(totalImageCount) pages")
            summaryRow(icon: "doc.text", label: "Story text & prompts",
                       value: "\(viewModel.storyBook.pages.count) pages")
            summaryRow(icon: "photo.stack", label: "Successful images",
                       value: "\(successfulCount) compressed")
            summaryRow(icon: "info.circle", label: "System info",
                       value: "App version, macOS version, Mac model")
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
            cornerRadius: StoryJuicerGlassTokens.Radius.card
        )
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: icon)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 18)

            Text(label)
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)

            Spacer()

            Text(value)
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjGlassInk)
                .lineLimit(1)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Text("Additional notes (optional)")
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(Color.sjGlassInk)

            TextEditor(text: $userNotes)
                .font(.system(.body, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(StoryJuicerGlassTokens.Spacing.small)
                .sjGlassCard(
                    tint: .sjGlassWeak,
                    cornerRadius: StoryJuicerGlassTokens.Radius.chip
                )
        }
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.sjGold)

            Text("Thank you!")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

            Text("Your report has been submitted. This helps us improve image generation for everyone.")
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.sjCoral)
        }
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.sjPaperTop, Color.sjPaperBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Submit Logic

    @MainActor
    private func submitReport() async {
        phase = .submitting

        do {
            let settings = ModelSelectionStore.load()
            let sysInfo = IssueReportService.systemInfo()

            let zipURL = try IssueReportService.buildReportZip(
                storyBook: viewModel.storyBook,
                images: viewModel.images,
                missingIndices: viewModel.missingImageIndices,
                format: viewModel.format,
                style: viewModel.illustrationStyle
            )

            let metadata = IssueReportService.ReportMetadata(
                bookTitle: viewModel.storyBook.title,
                pageCount: viewModel.storyBook.pages.count,
                missingIndices: viewModel.missingImageIndices,
                format: viewModel.format.rawValue,
                style: viewModel.illustrationStyle.rawValue,
                textProvider: settings.textProvider.rawValue,
                imageProvider: settings.imageProvider.rawValue,
                userNotes: userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : userNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                appVersion: sysInfo.appVersion,
                osVersion: sysInfo.osVersion,
                deviceModel: sysInfo.deviceModel
            )

            try await IssueReportService.submitReport(zipURL: zipURL, metadata: metadata)
            phase = .success
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
