#if DEBUG
import SwiftUI
import FoundationModels
import AppKit

/// Debug test harness for evaluating the full story generation pipeline.
/// Accessible via Debug > Test Character Harness (Cmd+Shift+T).
///
/// Three test modes:
/// 1. **Test LLM** — Generates a story and scores character consistency in imagePrompts
/// 2. **Test Prompts** — Inspects the ImagePlayground fallback variant chain (fast, no images)
/// 3. **Test Images** — Runs the full image generation pipeline and displays results
struct MacTestHarnessView: View {
    // MARK: - Existing State (LLM Test)

    @State private var isRunning = false
    @State private var result: ImagePromptEnricher.HarnessResult?
    @State private var errorMessage: String?
    @State private var statusText = ""
    @State private var showEnriched = true

    // MARK: - Mode 1 State (Prompt Test)

    @State private var promptTestResults: [PromptTestPageResult]?

    // MARK: - Mode 2 State (Analysis Test)

    @State private var analysisTestResults: [AnalysisTestPageResult]?
    @State private var analysisTestRunning = false

    // MARK: - Mode 3 State (Image Test)

    @State private var imageTestRunning = false
    @State private var imageTestImages: [Int: CGImage] = [:]
    @State private var imageTestVariantWins: [String: Int] = [:]
    @State private var imageTestDuration: TimeInterval?
    @State private var imageTestTotal = 0
    @State private var imageTestCompleted = 0

    // MARK: - Export State

    @State private var copyButtonLabel = "Copy Results"

    private let baselineConcept = "A curious fox building a moonlight library in the forest"
    private let expectedSpecies = "fox"
    private let testPageCount = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.large) {
                header
                controlsRow
                if let errorMessage {
                    errorBanner(errorMessage)
                }
                if let result {
                    scoreCard(result)
                    characterDescriptionSection(result)
                    pageDetailsSection(result)
                }
                if let promptTestResults {
                    promptTestSection(promptTestResults)
                }
                if let analysisTestResults {
                    analysisTestSection(analysisTestResults)
                }
                if !imageTestImages.isEmpty || imageTestRunning {
                    imageTestSection
                }
            }
            .padding(StoryJuicerGlassTokens.Spacing.xLarge)
        }
        .frame(minWidth: 740, minHeight: 560)
        .background(
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "flask")
                    .font(.title2)
                    .foregroundStyle(Color.sjCoral)
                Text("Character Consistency Test Harness")
                    .font(StoryJuicerTypography.settingsHero)
                    .foregroundStyle(Color.sjGlassInk)
            }

            Text("Tests the full pipeline: LLM text generation, prompt variant chain, and image generation.")
                .font(StoryJuicerTypography.settingsBody)
                .foregroundStyle(Color.sjSecondaryText)

            HStack(spacing: 4) {
                Text("Baseline:")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjSecondaryText)
                Text("\"\(baselineConcept)\"")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjGlassInk)
                    .italic()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                let settings = ModelSelectionStore.load()
                Text("Provider: \(settings.textProvider.displayName)")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)

                Spacer()

                if isRunning || imageTestRunning || analysisTestRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(statusText.isEmpty ? "Running..." : statusText)
                            .font(StoryJuicerTypography.uiMeta)
                            .foregroundStyle(Color.sjSecondaryText)
                    }
                }
            }

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                // Test LLM button — always available
                Button {
                    runTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                        Text("Test LLM")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjCoral)
                .disabled(isRunning || imageTestRunning || analysisTestRunning)

                // Test Prompts button — requires LLM result
                Button {
                    runPromptTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.magnifyingglass")
                        Text("Test Prompts")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjMint)
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Inspect the variant fallback chain")

                // Test Analysis button — requires LLM result
                Button {
                    runAnalysisTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Test Analysis")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjGold)
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Run Foundation Model prompt analysis on each page")

                // Test Images button — requires LLM result
                Button {
                    runImageTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack")
                        Text("Test Images")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjSky)
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Generate images with the full pipeline")

                Spacer()

                // Copy Results button — exports JSON to clipboard
                Button {
                    copyResultsToClipboard()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copyButtonLabel == "Copied!" ? "checkmark" : "doc.on.clipboard")
                        Text(copyButtonLabel)
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(copyButtonLabel == "Copied!" ? .green : .sjGlassInk)
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning)
                .help("Copy test results as JSON for pasting into Claude")
            }
        }
    }

    // MARK: - Score Card

    private func scoreCard(_ result: ImagePromptEnricher.HarnessResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Text("Score Card")
                .font(StoryJuicerTypography.settingsSectionTitle)
                .foregroundStyle(Color.sjGlassInk)

            VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                scoreRow(
                    label: "Character Description",
                    score: result.characterDescriptionScore,
                    detail: result.characterDescriptionScore >= 1.0
                        ? "Has species + appearance detail"
                        : "Missing species or detail"
                )
                scoreRow(
                    label: "Species in Prompts",
                    score: result.speciesInPromptsScore,
                    detail: "\(Int(result.speciesInPromptsScore * Double(result.details.count)))/\(result.details.count) pages contain \"\(expectedSpecies)\""
                )
                scoreRow(
                    label: "Appearance in Prompts",
                    score: result.appearanceInPromptsScore,
                    detail: "\(Int(result.appearanceInPromptsScore * Double(result.details.count)))/\(result.details.count) pages with color/clothing"
                )
                scoreRow(
                    label: "Name Consistency",
                    score: result.nameConsistencyScore,
                    detail: "\(Int(result.nameConsistencyScore * Double(result.details.count)))/\(result.details.count) pages mention character"
                )

                Divider()

                HStack {
                    Text("Overall Score")
                        .font(StoryJuicerTypography.uiBodyStrong)
                        .foregroundStyle(Color.sjGlassInk)
                    Spacer()
                    overallScoreBar(result.overallScore)
                }
            }
            .padding(StoryJuicerGlassTokens.Spacing.medium)
            .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
        }
    }

    private func scoreRow(label: String, score: Double, detail: String) -> some View {
        HStack {
            Image(systemName: score >= 0.75 ? "checkmark.circle.fill" : score >= 0.5 ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(score >= 0.75 ? .green : score >= 0.5 ? .orange : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)
                Text(detail)
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
            }
            Spacer()
            Text("\(Int(score * 100))%")
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(Color.sjGlassInk)
                .monospacedDigit()
        }
    }

    private func overallScoreBar(_ score: Double) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.sjMuted.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(score >= 0.75 ? Color.green : score >= 0.5 ? Color.orange : Color.red)
                        .frame(width: geo.size.width * score)
                }
            }
            .frame(width: 120, height: 12)

            Text("\(Int(score * 100))%")
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)
                .monospacedDigit()
        }
    }

    // MARK: - Character Description Section

    private func characterDescriptionSection(_ result: ImagePromptEnricher.HarnessResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text("Character Descriptions")
                .font(StoryJuicerTypography.settingsSectionTitle)
                .foregroundStyle(Color.sjGlassInk)

            Text(result.rawBook.characterDescriptions)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.sjGlassInk)
                .textSelection(.enabled)
                .padding(StoryJuicerGlassTokens.Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
        }
    }

    // MARK: - Page Details (LLM Test)

    private func pageDetailsSection(_ result: ImagePromptEnricher.HarnessResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack {
                Text("Raw vs Enriched Prompts")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Spacer()

                Toggle("Show Enriched", isOn: $showEnriched)
                    .font(StoryJuicerTypography.uiMeta)
                    .toggleStyle(.switch)
                    .tint(.sjCoral)
            }

            ForEach(result.details) { page in
                pageDetailRow(page)
            }
        }
    }

    private func pageDetailRow(_ page: ImagePromptEnricher.PageCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Page \(page.pageNumber)")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)

                checkBadge("Species", passed: page.hasSpecies)
                checkBadge("Appearance", passed: page.hasAppearance)
                checkBadge("Name", passed: page.hasCharacterName)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Raw:")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjSecondaryText)
                Text(page.rawImagePrompt)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
                    .textSelection(.enabled)
            }

            if showEnriched && page.rawImagePrompt != page.enrichedImagePrompt {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enriched:")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjCoral)
                    Text(page.enrichedImagePrompt)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                        .textSelection(.enabled)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.sjCoral)
                    Text("Species: \(page.hasSpecies ? "Present" : "Injected")")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            } else if showEnriched {
                Text("(unchanged — already well-described)")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .italic()
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    // MARK: - Prompt Test Section (Mode 1)

    private func promptTestSection(_ pages: [PromptTestPageResult]) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(Color.sjMint)
                Text("Variant Chain Inspection")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)
            }

            Text("Shows each fallback variant that ImagePlayground would try, with character counts and limit warnings.")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)

            ForEach(pages) { page in
                promptTestPageCard(page)
            }
        }
    }

    private func promptTestPageCard(_ page: PromptTestPageResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            // Page label
            Text(page.pageLabel)
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            // Enriched prompt preview
            VStack(alignment: .leading, spacing: 2) {
                Text("Enriched prompt:")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjSecondaryText)
                Text(page.enrichedPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            Divider()

            // Variant rows
            ForEach(Array(page.variants.enumerated()), id: \.offset) { index, variant in
                variantRow(variant, index: index)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    private func variantRow(_ variant: IllustrationGenerator.PromptVariantInfo, index: Int) -> some View {
        HStack(spacing: 8) {
            // Variant label
            Text(variant.label)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(Color.sjGlassInk)
                .frame(width: 100, alignment: .leading)

            // Char count badge
            let limitColor: Color = variant.exceedsLimit ? .red : variant.charCount > 150 ? .orange : .green
            Text("\(variant.charCount) chars")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(limitColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(limitColor.opacity(0.12), in: Capsule())
                .monospacedDigit()

            // Status indicator
            if variant.exceedsLimit {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("over limit")
                        .font(StoryJuicerTypography.uiMeta)
                }
                .foregroundStyle(.red)
            } else if variant.charCount > 150 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                    Text("near limit")
                        .font(StoryJuicerTypography.uiMeta)
                }
                .foregroundStyle(.orange)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                    Text("OK")
                        .font(StoryJuicerTypography.uiMeta)
                }
                .foregroundStyle(.green)
            }

            Spacer()

            // Truncated preview
            Text(variant.text.prefix(60) + (variant.text.count > 60 ? "..." : ""))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.sjSecondaryText)
                .lineLimit(1)
                .help(variant.text)
        }
    }

    // MARK: - Analysis Test Section

    private func analysisTestSection(_ pages: [AnalysisTestPageResult]) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(Color.sjGold)
                Text("Prompt Analysis Results")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)
            }

            // Aggregate score card
            analysisScoreCard(pages)

            // Per-page cards
            ForEach(pages) { page in
                analysisPageCard(page)
            }
        }
    }

    private func analysisScoreCard(_ pages: [AnalysisTestPageResult]) -> some View {
        let count = max(pages.count, 1)
        let speciesAcc = Double(pages.filter(\.speciesCorrect).count) / Double(count)
        let appearanceQual = Double(pages.filter(\.appearanceQuality).count) / Double(count)
        let sceneExt = Double(pages.filter(\.sceneExtracted).count) / Double(count)
        let actionExt = Double(pages.filter(\.actionExtracted).count) / Double(count)
        let methodAgree = Double(pages.filter(\.methodsAgree).count) / Double(count)
        let foundationAvailable = pages.contains { $0.llmAnalysis != nil }

        return VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            if !foundationAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Foundation Model unavailable — showing heuristic results only")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }

            scoreRow(label: "Species Accuracy", score: speciesAcc,
                     detail: "\(Int(speciesAcc * Double(count)))/\(count) pages identified \"\(expectedSpecies)\"")
            scoreRow(label: "Appearance Quality", score: appearanceQual,
                     detail: "\(Int(appearanceQual * Double(count)))/\(count) pages with visual descriptors")
            scoreRow(label: "Scene Extraction", score: sceneExt,
                     detail: "\(Int(sceneExt * Double(count)))/\(count) pages with scene setting")
            scoreRow(label: "Action Extraction", score: actionExt,
                     detail: "\(Int(actionExt * Double(count)))/\(count) pages with action/pose")
            scoreRow(label: "LLM/Heuristic Agreement", score: methodAgree,
                     detail: "\(Int(methodAgree * Double(count)))/\(count) pages where methods agree on species")
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    private func analysisPageCard(_ page: AnalysisTestPageResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            // Page header with badges
            HStack(spacing: 8) {
                Text(page.pageLabel)
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)

                checkBadge("Species", passed: page.speciesCorrect)
                checkBadge("Appear", passed: page.appearanceQuality)
                checkBadge("Scene", passed: page.sceneExtracted)
                checkBadge("Action", passed: page.actionExtracted)
                if page.llmAnalysis != nil {
                    checkBadge("Agree", passed: page.methodsAgree)
                }
            }

            // Original prompt
            VStack(alignment: .leading, spacing: 2) {
                Text("Prompt:")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjSecondaryText)
                Text(page.originalPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            Divider()

            // Side-by-side: LLM vs Heuristic
            HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
                if let llm = page.llmAnalysis {
                    analysisColumn(title: "Foundation Model", analysis: llm, tint: .sjCoral)
                }

                analysisColumn(title: "Heuristic", analysis: page.heuristicAnalysis, tint: .sjMint)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    private func analysisColumn(title: String, analysis: PromptAnalysis, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(tint)

            if analysis.characters.isEmpty {
                analysisField("Characters", value: "—")
            } else {
                ForEach(Array(analysis.characters.enumerated()), id: \.offset) { idx, char in
                    analysisField("Char \(idx + 1)", value: "\(char.species) · \(char.appearance)")
                }
            }
            analysisField("Scene", value: analysis.sceneSetting)
            analysisField("Action", value: analysis.mainAction)
            analysisField("Mood", value: analysis.mood)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func analysisField(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .foregroundStyle(Color.sjSecondaryText)
                .frame(width: 70, alignment: .trailing)
            Text(value.isEmpty ? "—" : value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(value.isEmpty ? Color.sjMuted : Color.sjGlassInk)
                .lineLimit(1)
        }
    }

    // MARK: - Image Test Section (Mode 2)

    private var imageTestSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .foregroundStyle(Color.sjSky)
                Text("Image Generation Results")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)
            }

            // Progress bar during generation
            if imageTestRunning {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Generating images...")
                            .font(StoryJuicerTypography.uiBodyStrong)
                            .foregroundStyle(Color.sjGlassInk)
                        Spacer()
                        Text("\(imageTestCompleted)/\(imageTestTotal)")
                            .font(StoryJuicerTypography.uiMetaStrong)
                            .foregroundStyle(Color.sjSecondaryText)
                            .monospacedDigit()
                    }

                    ProgressView(value: Double(imageTestCompleted), total: Double(max(imageTestTotal, 1)))
                        .tint(.sjCoral)
                }
                .padding(StoryJuicerGlassTokens.Spacing.medium)
                .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
            }

            // Image grid (2 columns)
            if !imageTestImages.isEmpty {
                let sortedKeys = imageTestImages.keys.sorted()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StoryJuicerGlassTokens.Spacing.medium) {
                    ForEach(sortedKeys, id: \.self) { index in
                        if let cgImage = imageTestImages[index] {
                            VStack(spacing: 6) {
                                Image(decorative: cgImage, scale: 1.0)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                                Text(index == 0 ? "Cover" : "Page \(index)")
                                    .font(StoryJuicerTypography.uiMetaStrong)
                                    .foregroundStyle(Color.sjGlassInk)
                            }
                        }
                    }
                }
            }

            // Variant win summary + duration
            if !imageTestRunning && !imageTestVariantWins.isEmpty {
                variantWinSummary
            }
        }
    }

    private var variantWinSummary: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text("Variant Win Distribution")
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            let sortedWins = imageTestVariantWins.sorted { a, b in
                // Sort by the variant chain order
                let order = ["sanitized", "llmRewritten", "shortened", "highReliability", "fallback", "ultraSafe"]
                let ai = order.firstIndex(of: a.key) ?? order.count
                let bi = order.firstIndex(of: b.key) ?? order.count
                return ai < bi
            }

            ForEach(sortedWins, id: \.key) { label, count in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                        .frame(width: 120, alignment: .leading)

                    // Bar chart
                    let maxCount = imageTestVariantWins.values.max() ?? 1
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(variantColor(for: label))
                            .frame(width: geo.size.width * (Double(count) / Double(maxCount)))
                    }
                    .frame(height: 14)

                    Text("\(count)")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjGlassInk)
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }

            if let duration = imageTestDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.sjSecondaryText)
                    Text("Total: \(String(format: "%.1f", duration))s")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)

                    Spacer()

                    let successCount = imageTestImages.count
                    Text("\(successCount)/\(imageTestTotal) succeeded")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(successCount == imageTestTotal ? .green : .orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    private func variantColor(for label: String) -> Color {
        switch label {
        case "sanitized": return .green
        case "llmRewritten": return .teal
        case "shortened": return .blue
        case "highReliability": return .orange
        case "fallback": return .purple
        case "ultraSafe": return .red
        default: return .gray
        }
    }

    // MARK: - Shared Components

    private func checkBadge(_ label: String, passed: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: passed ? "checkmark" : "xmark")
                .font(.caption2.weight(.bold))
            Text(label)
                .font(StoryJuicerTypography.uiMeta)
        }
        .foregroundStyle(passed ? .green : .red)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (passed ? Color.green : Color.red).opacity(0.12),
            in: Capsule()
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(StoryJuicerTypography.settingsBody)
                .foregroundStyle(Color.sjGlassInk)
                .textSelection(.enabled)
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sjGlassCard(tint: Color.red.opacity(0.08), cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    // MARK: - Test Execution: LLM (Existing)

    private func runTest() {
        guard !isRunning else { return }
        isRunning = true
        result = nil
        errorMessage = nil
        promptTestResults = nil
        analysisTestResults = nil
        imageTestImages = [:]
        imageTestVariantWins = [:]
        imageTestDuration = nil
        statusText = "Generating story..."

        Task {
            do {
                let rawBook = try await generateTestStory()
                statusText = "Evaluating character consistency..."

                let harnessResult = ImagePromptEnricher.evaluate(
                    rawBook: rawBook,
                    expectedSpecies: expectedSpecies,
                    concept: baselineConcept
                )

                await MainActor.run {
                    result = harnessResult
                    isRunning = false
                    statusText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                    statusText = ""
                }
            }
        }
    }

    // MARK: - Test Execution: Prompt Test (Mode 1)

    private func runPromptTest() {
        guard let result else { return }
        // Use enrichedBook — ImagePromptEnricher has added inline species descriptors.
        // enrichPromptWithCharacters() detects this and skips the "Featuring..." prefix
        // for pages, while still adding it for cover prompts that lack character names.
        let book = result.enrichedBook
        let illustrator = IllustrationGenerator()

        var results: [PromptTestPageResult] = []

        // Cover
        let coverPrompt = ContentSafetyPolicy.safeCoverPrompt(
            title: book.title,
            concept: baselineConcept
        )
        let coverEnriched = IllustrationGenerator.enrichPromptWithCharacters(
            coverPrompt,
            characterDescriptions: book.characterDescriptions
        )
        let coverVariants = illustrator.inspectVariantChain(
            for: coverPrompt,
            characterDescriptions: book.characterDescriptions
        )
        results.append(PromptTestPageResult(
            pageLabel: "Cover",
            originalPrompt: coverPrompt,
            enrichedPrompt: coverEnriched,
            variants: coverVariants
        ))

        // Pages
        for page in book.pages {
            let pageEnriched = IllustrationGenerator.enrichPromptWithCharacters(
                page.imagePrompt,
                characterDescriptions: book.characterDescriptions
            )
            let variants = illustrator.inspectVariantChain(
                for: page.imagePrompt,
                characterDescriptions: book.characterDescriptions
            )
            results.append(PromptTestPageResult(
                pageLabel: "Page \(page.pageNumber)",
                originalPrompt: page.imagePrompt,
                enrichedPrompt: pageEnriched,
                variants: variants
            ))
        }

        promptTestResults = results
    }

    // MARK: - Test Execution: Analysis Test

    private func runAnalysisTest() {
        guard let result else { return }
        let book = result.enrichedBook
        analysisTestRunning = true
        analysisTestResults = nil
        statusText = "Analyzing prompts with Foundation Model..."

        Task {
            var pages: [AnalysisTestPageResult] = []

            // Build prompt list: cover + story pages
            let coverPrompt = ContentSafetyPolicy.safeCoverPrompt(
                title: book.title,
                concept: baselineConcept
            )
            var promptList: [(label: String, index: Int, prompt: String)] = [
                ("Cover", 0, coverPrompt)
            ]
            for page in book.pages {
                promptList.append(("Page \(page.pageNumber)", page.pageNumber, page.imagePrompt))
            }

            // Batch LLM analysis
            let prompts = promptList.map { (index: $0.index, prompt: $0.prompt) }
            let llmAnalyses = await PromptAnalysisEngine.analyzePrompts(prompts)

            for item in promptList {
                let llmAnalysis = llmAnalyses[item.index]
                let heuristicAnalysis = PromptAnalysisEngine.heuristicAnalysis(of: item.prompt)

                let expectedLower = expectedSpecies.lowercased()

                // Extract species lists from both methods
                let llmSpeciesList = llmAnalysis?.characters.map { $0.species.lowercased() } ?? []
                let heuristicSpeciesList = heuristicAnalysis.characters.map { $0.species.lowercased() }

                // Union of all species found across both methods
                let allFoundSpecies = Array(Set(llmSpeciesList + heuristicSpeciesList)).sorted()
                let speciesCorrect = allFoundSpecies.contains(expectedLower)

                // Appearance quality: check best available source
                let appearance = llmAnalysis?.primaryAppearance ?? heuristicAnalysis.primaryAppearance
                let appearanceQuality = !appearance.isEmpty && appearance.split(whereSeparator: \.isWhitespace).count >= 2

                let scene = llmAnalysis?.sceneSetting ?? heuristicAnalysis.sceneSetting
                let sceneExtracted = !scene.isEmpty

                let action = llmAnalysis?.mainAction ?? heuristicAnalysis.mainAction
                let actionExtracted = !action.isEmpty

                // Methods agree if their primary species match
                let methodsAgree: Bool
                if llmAnalysis != nil {
                    let llmPrimary = llmSpeciesList.first ?? ""
                    let heuristicPrimary = heuristicSpeciesList.first ?? ""
                    methodsAgree = llmPrimary == heuristicPrimary
                        || llmPrimary.contains(heuristicPrimary)
                        || heuristicPrimary.contains(llmPrimary)
                } else {
                    methodsAgree = true // Only one method — trivially agrees
                }

                pages.append(AnalysisTestPageResult(
                    pageLabel: item.label,
                    originalPrompt: item.prompt,
                    llmAnalysis: llmAnalysis,
                    heuristicAnalysis: heuristicAnalysis,
                    speciesFound: allFoundSpecies,
                    speciesCorrect: speciesCorrect,
                    appearanceQuality: appearanceQuality,
                    sceneExtracted: sceneExtracted,
                    actionExtracted: actionExtracted,
                    methodsAgree: methodsAgree
                ))
            }

            await MainActor.run {
                analysisTestResults = pages
                analysisTestRunning = false
                statusText = ""
            }
        }
    }

    // MARK: - Test Execution: Image Test (Mode 2)

    private func runImageTest() {
        guard let result else { return }
        // Use enrichedBook — generateIllustrations uses enrichPromptWithCharacters which
        // detects inline species and skips the prefix for already-enriched pages.
        let book = result.enrichedBook
        imageTestRunning = true
        imageTestImages = [:]
        imageTestVariantWins = [:]
        imageTestDuration = nil
        imageTestTotal = book.pages.count + 1
        imageTestCompleted = 0
        statusText = "Generating images..."

        Task {
            let illustrator = IllustrationGenerator()
            let start = ContinuousClock.now

            do {
                try await illustrator.generateIllustrations(
                    for: book.pages,
                    coverPrompt: ContentSafetyPolicy.safeCoverPrompt(
                        title: book.title,
                        concept: baselineConcept
                    ),
                    characterDescriptions: book.characterDescriptions,
                    style: .illustration,
                    format: .standard
                ) { index, image in
                    imageTestImages[index] = image
                    imageTestCompleted += 1
                }
            } catch is CancellationError {
                // User cancelled — no-op
            } catch {
                errorMessage = "Image test failed: \(error.localizedDescription)"
            }

            let elapsed = start.duration(to: .now)
            imageTestDuration = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            imageTestVariantWins = illustrator.variantSuccessCounts
            imageTestRunning = false
            statusText = ""
        }
    }

    // MARK: - JSON Export

    private func copyResultsToClipboard() {
        guard let json = buildExportJSON() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)

        copyButtonLabel = "Copied!"
        Task {
            try? await Task.sleep(for: .seconds(2))
            copyButtonLabel = "Copy Results"
        }
    }

    private func buildExportJSON() -> String? {
        guard let result else { return nil }

        let settings = ModelSelectionStore.load()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // Metadata
        let metadata = TestHarnessExport.Metadata(
            concept: baselineConcept,
            expectedSpecies: expectedSpecies,
            pageCount: testPageCount,
            textProvider: settings.textProvider.displayName,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            appVersion: appVersion
        )

        // LLM test (always present when result exists)
        let verdict: String = result.overallScore >= 0.75 ? "pass" : result.overallScore >= 0.50 ? "marginal" : "fail"
        let llmPages = result.details.map { page in
            TestHarnessExport.LLMTest.PageDetail(
                pageNumber: page.pageNumber,
                hasSpecies: page.hasSpecies,
                hasAppearance: page.hasAppearance,
                hasCharacterName: page.hasCharacterName,
                rawImagePrompt: page.rawImagePrompt,
                enrichedImagePrompt: page.enrichedImagePrompt
            )
        }
        let llmTest = TestHarnessExport.LLMTest(
            scores: TestHarnessExport.LLMTest.Scores(
                overall: result.overallScore,
                characterDescription: result.characterDescriptionScore,
                speciesInPrompts: result.speciesInPromptsScore,
                appearanceInPrompts: result.appearanceInPromptsScore,
                nameConsistency: result.nameConsistencyScore
            ),
            verdict: verdict,
            characterDescriptions: result.rawBook.characterDescriptions,
            pages: llmPages
        )

        // Prompt test (optional)
        var promptTest: TestHarnessExport.PromptTest?
        if let promptTestResults {
            let pages = promptTestResults.map { page in
                let variants = page.variants.map { v in
                    TestHarnessExport.PromptTest.PageDetail.Variant(
                        label: v.label,
                        text: v.text,
                        charCount: v.charCount,
                        exceedsLimit: v.exceedsLimit
                    )
                }
                return TestHarnessExport.PromptTest.PageDetail(
                    pageLabel: page.pageLabel,
                    originalPrompt: page.originalPrompt,
                    enrichedPrompt: page.enrichedPrompt,
                    variants: variants
                )
            }
            promptTest = TestHarnessExport.PromptTest(pages: pages)
        }

        // Analysis test (optional)
        var analysisTest: TestHarnessExport.AnalysisTest?
        if let analysisTestResults {
            let count = max(analysisTestResults.count, 1)
            let scores = TestHarnessExport.AnalysisTest.Scores(
                speciesAccuracy: Double(analysisTestResults.filter(\.speciesCorrect).count) / Double(count),
                appearanceQuality: Double(analysisTestResults.filter(\.appearanceQuality).count) / Double(count),
                sceneExtraction: Double(analysisTestResults.filter(\.sceneExtracted).count) / Double(count),
                actionExtraction: Double(analysisTestResults.filter(\.actionExtracted).count) / Double(count),
                methodAgreement: Double(analysisTestResults.filter(\.methodsAgree).count) / Double(count)
            )
            let pages = analysisTestResults.map { page in
                TestHarnessExport.AnalysisTest.PageDetail(
                    pageLabel: page.pageLabel,
                    originalPrompt: page.originalPrompt,
                    llmSpecies: page.llmAnalysis?.characters.map(\.species),
                    llmAppearance: page.llmAnalysis?.primaryAppearance,
                    llmScene: page.llmAnalysis?.sceneSetting,
                    llmAction: page.llmAnalysis?.mainAction,
                    llmMood: page.llmAnalysis?.mood,
                    heuristicSpecies: page.heuristicAnalysis.characters.map(\.species),
                    heuristicAppearance: page.heuristicAnalysis.primaryAppearance,
                    speciesCorrect: page.speciesCorrect,
                    methodsAgree: page.methodsAgree
                )
            }
            analysisTest = TestHarnessExport.AnalysisTest(
                foundationModelAvailable: analysisTestResults.contains { $0.llmAnalysis != nil },
                scores: scores,
                pages: pages
            )
        }

        // Image test (optional)
        var imageTest: TestHarnessExport.ImageTest?
        if imageTestDuration != nil || !imageTestImages.isEmpty {
            imageTest = TestHarnessExport.ImageTest(
                totalDurationSeconds: imageTestDuration ?? 0,
                successCount: imageTestImages.count,
                totalCount: imageTestTotal,
                variantWins: imageTestVariantWins
            )
        }

        let export = TestHarnessExport(
            metadata: metadata,
            llmTest: llmTest,
            promptTest: promptTest,
            analysisTest: analysisTest,
            imageTest: imageTest
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(export) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Story Generation Helpers

    @MainActor
    private func generateTestStory() async throws -> StoryBook {
        let settings = ModelSelectionStore.load()

        switch settings.textProvider {
        case .appleFoundation:
            return try await generateFoundationStory()
        case .mlxSwift:
            let generator = MLXStoryGenerator()
            return try await generator.generateStory(
                concept: baselineConcept,
                pageCount: testPageCount,
                onProgress: { text in
                    statusText = "MLX: \(text.prefix(60))..."
                }
            )
        case .openRouter, .togetherAI, .huggingFace:
            guard let cloudProvider = settings.textProvider.cloudProvider else {
                throw TestHarnessError.providerUnavailable
            }
            let generator = CloudTextGenerator(cloudProvider: cloudProvider)
            return try await generator.generateStory(
                concept: baselineConcept,
                pageCount: testPageCount,
                onProgress: { text in
                    statusText = "Cloud: \(text.prefix(60))..."
                }
            )
        }
    }

    @MainActor
    private func generateFoundationStory() async throws -> StoryBook {
        let storyGenerator = StoryGenerator()
        guard storyGenerator.isAvailable else {
            throw TestHarnessError.providerUnavailable
        }
        return try await storyGenerator.generateStory(
            concept: baselineConcept,
            pageCount: testPageCount
        ) { partialText in
            statusText = "Foundation: \(partialText.prefix(60))..."
        }
    }
}

// MARK: - Data Types

struct PromptTestPageResult: Identifiable {
    let id = UUID()
    let pageLabel: String
    let originalPrompt: String
    let enrichedPrompt: String
    let variants: [IllustrationGenerator.PromptVariantInfo]
}

struct AnalysisTestPageResult: Identifiable {
    let id = UUID()
    let pageLabel: String
    let originalPrompt: String
    let llmAnalysis: PromptAnalysis?
    let heuristicAnalysis: PromptAnalysis
    let speciesFound: [String]
    let speciesCorrect: Bool
    let appearanceQuality: Bool
    let sceneExtracted: Bool
    let actionExtracted: Bool
    let methodsAgree: Bool
}

// MARK: - Errors

private enum TestHarnessError: LocalizedError {
    case providerUnavailable

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "The selected text provider is not available. Check your settings."
        }
    }
}

// MARK: - Export Data Model

/// Codable export format for pasting test harness results into Claude conversations.
private struct TestHarnessExport: Codable {
    let metadata: Metadata
    let llmTest: LLMTest
    let promptTest: PromptTest?
    let analysisTest: AnalysisTest?
    let imageTest: ImageTest?

    struct Metadata: Codable {
        let concept: String
        let expectedSpecies: String
        let pageCount: Int
        let textProvider: String
        let timestamp: String
        let appVersion: String
    }

    struct LLMTest: Codable {
        let scores: Scores
        let verdict: String
        let characterDescriptions: String
        let pages: [PageDetail]

        struct Scores: Codable {
            let overall: Double
            let characterDescription: Double
            let speciesInPrompts: Double
            let appearanceInPrompts: Double
            let nameConsistency: Double
        }

        struct PageDetail: Codable {
            let pageNumber: Int
            let hasSpecies: Bool
            let hasAppearance: Bool
            let hasCharacterName: Bool
            let rawImagePrompt: String
            let enrichedImagePrompt: String
        }
    }

    struct PromptTest: Codable {
        let pages: [PageDetail]

        struct PageDetail: Codable {
            let pageLabel: String
            let originalPrompt: String
            let enrichedPrompt: String
            let variants: [Variant]

            struct Variant: Codable {
                let label: String
                let text: String
                let charCount: Int
                let exceedsLimit: Bool
            }
        }
    }

    struct AnalysisTest: Codable {
        let foundationModelAvailable: Bool
        let scores: Scores
        let pages: [PageDetail]

        struct Scores: Codable {
            let speciesAccuracy: Double
            let appearanceQuality: Double
            let sceneExtraction: Double
            let actionExtraction: Double
            let methodAgreement: Double
        }

        struct PageDetail: Codable {
            let pageLabel: String
            let originalPrompt: String
            let llmSpecies: [String]?
            let llmAppearance: String?
            let llmScene: String?
            let llmAction: String?
            let llmMood: String?
            let heuristicSpecies: [String]
            let heuristicAppearance: String
            let speciesCorrect: Bool
            let methodsAgree: Bool
        }
    }

    struct ImageTest: Codable {
        let totalDurationSeconds: TimeInterval
        let successCount: Int
        let totalCount: Int
        let variantWins: [String: Int]
    }
}
#endif
