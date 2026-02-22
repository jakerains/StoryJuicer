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

    // MARK: - Parsing Comparison State (Upgrade 1)

    @State private var parsingTestResult: ParsingTestResult?
    @State private var parsingTestRunning = false

    // MARK: - A/B Test State (Two-Pass Experiment)

    @State private var abTestResult: ABTestResult?
    @State private var abTestRunning = false

    // MARK: - A/B Image Generation State

    @State private var abImageTestRunning = false
    @State private var abImagesA: [Int: CGImage] = [:]
    @State private var abImagesB: [Int: CGImage] = [:]
    @State private var abImageCompleted = 0
    @State private var abImageTotal = 0

    // MARK: - Mode 3 State (Image Test)

    @State private var imageTestRunning = false
    @State private var imageTestImages: [Int: CGImage] = [:]
    @State private var imageTestVariantWins: [String: Int] = [:]
    @State private var imageTestDuration: TimeInterval?
    @State private var imageTestTotal = 0
    @State private var imageTestCompleted = 0
    @State private var useReferenceImage = false
    @State private var imageTestConcepts: [Int: ImageConceptDecomposition] = [:]

    // MARK: - Export State

    @State private var copyButtonLabel = "Copy Results"

    @State private var baselineConcept = "A curious fox building a moonlight library in the forest"
    @State private var expectedSpecies = "fox"
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
                if let parsingTestResult {
                    parsingComparisonSection(parsingTestResult)
                }
                if let promptTestResults {
                    promptTestSection(promptTestResults)
                }
                if let analysisTestResults {
                    analysisTestSection(analysisTestResults)
                }
                if let abTestResult {
                    abTestSection(abTestResult)
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Concept:")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjSecondaryText)
                        .frame(width: 60, alignment: .trailing)
                    TextField("Story concept...", text: $baselineConcept)
                        .textFieldStyle(.plain)
                        .font(StoryJuicerTypography.settingsBody)
                        .padding(8)
                        .settingsFieldChrome()
                        .onChange(of: baselineConcept) {
                            expectedSpecies = autoDetectSpecies(from: baselineConcept)
                        }
                }

                HStack(spacing: 8) {
                    Text("Species:")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjSecondaryText)
                        .frame(width: 60, alignment: .trailing)
                    TextField("Expected species...", text: $expectedSpecies)
                        .textFieldStyle(.plain)
                        .font(StoryJuicerTypography.settingsBody)
                        .padding(8)
                        .settingsFieldChrome()
                        .frame(width: 160)
                    Text("Auto-detected from concept")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText.opacity(0.6))
                }
            }
            .padding(.top, 4)
        }
    }

    /// Auto-detect the primary species from the concept using the same word list
    /// that `ImagePromptEnricher` uses for species detection.
    private func autoDetectSpecies(from concept: String) -> String {
        let words = concept.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        return words.first(where: { ImagePromptEnricher.speciesWords.contains($0) }) ?? ""
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

                if isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning {
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
                .disabled(isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)

                // Test Parsing button — requires LLM result (Upgrade 1)
                Button {
                    runParsingTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.viewfinder")
                        Text("Test Parsing")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjGold.opacity(0.8))
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Compare regex vs Foundation Model character parsing")

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
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
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
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
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
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Generate images with the full pipeline")

                // Test A/B button — requires LLM result, Foundation Models only
                Button {
                    runABTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Test A/B")
                    }
                    .font(StoryJuicerTypography.uiBodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(.sjLavender)
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
                .help(result == nil ? "Run Test LLM first" : "Compare single-pass vs two-pass generation")

                // Reference image toggle — A/B test: cover as ref vs prompt-only
                Toggle(isOn: $useReferenceImage) {
                    Label("Ref Image", systemImage: useReferenceImage ? "photo.badge.checkmark" : "photo.badge.minus")
                        .font(StoryJuicerTypography.uiFootnoteStrong)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("When on, cover image is passed as a reference for Page 1. Turn off to test prompt-only generation.")

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
                .disabled(result == nil || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning || abImageTestRunning)
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
            HStack(spacing: 8) {
                Text("Character Descriptions")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)

                if CharacterDescriptionValidator.lastRepairUsedFoundationModel {
                    HStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                        Text("FM Repaired")
                            .font(StoryJuicerTypography.uiMeta)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

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

            // Image grid (2 columns) with concept detail
            if !imageTestImages.isEmpty {
                let sortedKeys = imageTestImages.keys.sorted()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StoryJuicerGlassTokens.Spacing.medium) {
                    ForEach(sortedKeys, id: \.self) { index in
                        if let cgImage = imageTestImages[index] {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(decorative: cgImage, scale: 1.0)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                                Text(index == 0 ? "Cover" : "Page \(index)")
                                    .font(StoryJuicerTypography.uiMetaStrong)
                                    .foregroundStyle(Color.sjGlassInk)

                                // Show the concepts used for this image
                                if let decomposition = imageTestConcepts[index] {
                                    conceptChips(decomposition.concepts)
                                }
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
                // Multi-concept variants sort first (by concept count descending),
                // then single-string variants in chain order.
                let singleOrder = ["sanitized", "llmRewritten", "shortened", "highReliability", "fallback", "ultraSafe"]
                let aIsMulti = a.key.hasPrefix("multiConcept_")
                let bIsMulti = b.key.hasPrefix("multiConcept_")
                if aIsMulti && bIsMulti {
                    // Higher concept count first
                    let aNum = Int(a.key.dropFirst("multiConcept_".count)) ?? 0
                    let bNum = Int(b.key.dropFirst("multiConcept_".count)) ?? 0
                    return aNum > bNum
                }
                if aIsMulti { return true }
                if bIsMulti { return false }
                let ai = singleOrder.firstIndex(of: a.key) ?? singleOrder.count
                let bi = singleOrder.firstIndex(of: b.key) ?? singleOrder.count
                return ai < bi
            }

            ForEach(sortedWins, id: \.key) { label, count in
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                        .frame(width: 150, alignment: .leading)

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

    /// Compact label-colored chips showing the ranked concepts used for an image.
    private func conceptChips(_ concepts: [RankedImageConcept]) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(concepts.enumerated()), id: \.offset) { idx, concept in
                HStack(spacing: 3) {
                    Text("\(idx + 1).")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(conceptLabelColor(concept.label).opacity(0.8))
                    Text("\(concept.label): \(concept.value)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    conceptLabelColor(concept.label).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
        }
    }

    private func conceptLabelColor(_ label: String) -> Color {
        switch label.uppercased() {
        case "CHARACTER": return .sjCoral
        case "SETTING": return .sjSky
        case "ACTION": return .green
        case "DETAIL": return .purple
        case "PROPS": return .sjGold
        case "ATMOSPHERE": return .teal
        default: return .gray
        }
    }

    private func variantColor(for label: String) -> Color {
        switch label {
        case "sanitized": return .green
        case "llmRewritten": return .teal
        case "shortened": return .blue
        case "highReliability": return .orange
        case "fallback": return .purple
        case "ultraSafe": return .red
        default:
            // Multi-concept variants get a gradient from green (many) to orange (few)
            if label.hasPrefix("multiConcept_") { return .sjSky }
            return .gray
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
        parsingTestResult = nil
        abTestResult = nil
        abImagesA = [:]
        abImagesB = [:]
        imageTestImages = [:]
        imageTestVariantWins = [:]
        imageTestConcepts = [:]
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

    // MARK: - Test Execution: Parsing Comparison (Upgrade 1)

    private func runParsingTest() {
        guard let result else { return }
        parsingTestRunning = true
        parsingTestResult = nil
        statusText = "Parsing characters with regex and Foundation Model..."

        Task {
            let descriptions = result.rawBook.characterDescriptions

            // Regex parsing (sync)
            let regexParsed = ImagePromptEnricher.parseCharacterDescriptions(descriptions)

            // Foundation Model parsing (async)
            let fmParsed = await ImagePromptEnricher.parseCharacterDescriptionsAsync(descriptions)

            // Determine if FM was actually used (different results = FM contributed)
            let fmWasUsed = regexParsed.count != fmParsed.count
                || zip(regexParsed, fmParsed).contains { a, b in a.species != b.species }

            await MainActor.run {
                parsingTestResult = ParsingTestResult(
                    characterDescriptions: descriptions,
                    regexParsed: regexParsed,
                    foundationModelParsed: fmParsed,
                    foundationModelUsed: fmWasUsed
                )
                parsingTestRunning = false
                statusText = ""
            }
        }
    }

    // MARK: - Parsing Comparison UI

    private func parsingComparisonSection(_ result: ParsingTestResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(Color.sjGold)
                Text("Character Parsing Comparison")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)

                if result.foundationModelUsed {
                    HStack(spacing: 3) {
                        Image(systemName: "brain")
                            .font(.caption2)
                        Text("FM Active")
                            .font(StoryJuicerTypography.uiMeta)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12), in: Capsule())
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                        Text("FM Unavailable")
                            .font(StoryJuicerTypography.uiMeta)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            // Side-by-side table
            let maxCount = max(result.regexParsed.count, result.foundationModelParsed.count)
            ForEach(0..<maxCount, id: \.self) { idx in
                HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
                    // Regex column
                    if idx < result.regexParsed.count {
                        let entry = result.regexParsed[idx]
                        characterEntryColumn(
                            title: "Regex",
                            tint: .sjMint,
                            name: entry.name,
                            species: entry.species,
                            injection: entry.injectionPhrase
                        )
                    } else {
                        characterEntryColumn(title: "Regex", tint: .sjMint, name: "—", species: "—", injection: "—")
                    }

                    // FM column
                    if idx < result.foundationModelParsed.count {
                        let entry = result.foundationModelParsed[idx]
                        let speciesDiffers = idx < result.regexParsed.count && entry.species != result.regexParsed[idx].species
                        characterEntryColumn(
                            title: "Foundation Model",
                            tint: .sjCoral,
                            name: entry.name,
                            species: entry.species,
                            injection: entry.injectionPhrase,
                            highlight: speciesDiffers
                        )
                    } else {
                        characterEntryColumn(title: "Foundation Model", tint: .sjCoral, name: "—", species: "—", injection: "—")
                    }
                }
                .padding(StoryJuicerGlassTokens.Spacing.medium)
                .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
            }
        }
    }

    private func characterEntryColumn(
        title: String,
        tint: Color,
        name: String,
        species: String,
        injection: String,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(tint)

            HStack(spacing: 4) {
                Text("Name:")
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.sjSecondaryText)
                    .frame(width: 60, alignment: .trailing)
                Text(name)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
            }

            HStack(spacing: 4) {
                Text("Species:")
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.sjSecondaryText)
                    .frame(width: 60, alignment: .trailing)
                Text(species.isEmpty ? "—" : species)
                    .font(.system(.caption2, design: .monospaced).weight(highlight ? .bold : .regular))
                    .foregroundStyle(highlight ? .orange : Color.sjGlassInk)
            }

            HStack(alignment: .top, spacing: 4) {
                Text("Inject:")
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.sjSecondaryText)
                    .frame(width: 60, alignment: .trailing)
                Text(injection)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            illustrator.useReferenceImage = useReferenceImage
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
            imageTestConcepts = illustrator.conceptDecompositions
            imageTestRunning = false
            statusText = ""
        }
    }

    // MARK: - A/B Test Section (Two-Pass Experiment)

    private func abTestSection(_ abResult: ABTestResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(Color.sjLavender)
                Text("A/B Comparison: Single-Pass vs Two-Pass")
                    .font(StoryJuicerTypography.settingsSectionTitle)
                    .foregroundStyle(Color.sjGlassInk)
            }

            Text("Method A = single-pass (simultaneous text + prompts). Method B = two-pass (text first, then prompts with full context).")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)

            // Score comparison cards
            abScoreComparison(abResult)

            // Generate A/B Images action card
            VStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visual Comparison")
                            .font(StoryJuicerTypography.uiBodyStrong)
                            .foregroundStyle(Color.sjGlassInk)
                        Text("Generate images from both A and B prompts to compare visual output side-by-side.")
                            .font(StoryJuicerTypography.uiMeta)
                            .foregroundStyle(Color.sjSecondaryText)
                    }

                    Spacer()

                    Button {
                        runABImageTest()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(abImagesA.isEmpty && abImagesB.isEmpty ? "Generate A/B Images" : "Regenerate")
                        }
                        .font(StoryJuicerTypography.uiBodyStrong)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.sjCoral)
                    .disabled(abImageTestRunning || isRunning || imageTestRunning || analysisTestRunning || parsingTestRunning || abTestRunning)
                }

                if abImageTestRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Generating images...")
                                .font(StoryJuicerTypography.uiBodyStrong)
                                .foregroundStyle(Color.sjGlassInk)
                            Spacer()
                            Text("\(abImageCompleted)/\(abImageTotal)")
                                .font(StoryJuicerTypography.uiMetaStrong)
                                .foregroundStyle(Color.sjSecondaryText)
                                .monospacedDigit()
                        }
                        ProgressView(value: Double(abImageCompleted), total: Double(max(abImageTotal, 1)))
                            .tint(.sjLavender)
                    }
                } else if !abImagesA.isEmpty || !abImagesB.isEmpty {
                    let totalSucceeded = abImagesA.count + abImagesB.count
                    HStack(spacing: 4) {
                        Image(systemName: totalSucceeded == abImageTotal ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(totalSucceeded == abImageTotal ? .green : .orange)
                        Text("\(totalSucceeded)/\(abImageTotal) images generated")
                            .font(StoryJuicerTypography.uiMetaStrong)
                            .foregroundStyle(totalSucceeded == abImageTotal ? .green : .orange)
                    }
                }
            }
            .padding(StoryJuicerGlassTokens.Spacing.medium)
            .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)

            // A/B image comparison grid (shown during and after generation)
            if !abImagesA.isEmpty || !abImagesB.isEmpty || abImageTestRunning {
                abImageComparisonGrid(abResult)
            }

            // Character descriptions from Method B
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                Text("Method B Character Descriptions")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)
                Text(abResult.methodBCharacterDescriptions)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.sjGlassInk)
                    .textSelection(.enabled)
                    .padding(StoryJuicerGlassTokens.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
            }

            // Per-page prompt comparison
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                Text("Per-Page Prompt Comparison")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)

                ForEach(abResult.perPage) { page in
                    abPageComparisonRow(page)
                }
            }
        }
    }

    private func abScoreComparison(_ abResult: ABTestResult) -> some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            abScoreRow(label: "Overall", scoreA: abResult.methodA.overall, scoreB: abResult.methodB.overall)
            abScoreRow(label: "Species in Prompts", scoreA: abResult.methodA.species, scoreB: abResult.methodB.species)
            abScoreRow(label: "Appearance in Prompts", scoreA: abResult.methodA.appearance, scoreB: abResult.methodB.appearance)
            abScoreRow(label: "Name Consistency", scoreA: abResult.methodA.name, scoreB: abResult.methodB.name)

            Divider()

            HStack {
                Text("Verdict")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)
                Spacer()
                verdictBadge("A", verdict: abResult.methodA.verdict, tint: .sjCoral)
                verdictBadge("B", verdict: abResult.methodB.verdict, tint: .sjLavender)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    private func abScoreRow(label: String, scoreA: Double, scoreB: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)
                .frame(width: 160, alignment: .leading)

            // Method A bar
            HStack(spacing: 4) {
                Text("A")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjCoral)
                    .frame(width: 14)
                abScoreBar(score: scoreA, tint: .sjCoral)
                Text("\(Int(scoreA * 100))%")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjGlassInk)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            // Method B bar
            HStack(spacing: 4) {
                Text("B")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjLavender)
                    .frame(width: 14)
                abScoreBar(score: scoreB, tint: .sjLavender)
                Text("\(Int(scoreB * 100))%")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjGlassInk)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            // Delta indicator
            let delta = scoreB - scoreA
            if abs(delta) > 0.01 {
                Text(delta > 0 ? "+\(Int(delta * 100))%" : "\(Int(delta * 100))%")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(delta > 0 ? .green : .red)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            } else {
                Text("=")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjSecondaryText)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func abScoreBar(score: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.sjMuted.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: geo.size.width * score)
            }
        }
        .frame(width: 80, height: 10)
    }

    private func verdictBadge(_ method: String, verdict: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(method)
                .font(StoryJuicerTypography.uiMetaStrong)
            Text(verdict)
                .font(StoryJuicerTypography.uiMeta)
        }
        .foregroundStyle(verdict == "pass" ? .green : verdict == "marginal" ? .orange : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func abPageComparisonRow(_ page: ABTestResult.PageComparison) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Page \(page.pageNumber)")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjGlassInk)

                // Method A badges
                HStack(spacing: 2) {
                    Text("A:")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjCoral)
                    checkBadge("Sp", passed: page.aHasSpecies)
                    checkBadge("Ap", passed: page.aHasAppearance)
                }

                // Method B badges
                HStack(spacing: 2) {
                    Text("B:")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjLavender)
                    checkBadge("Sp", passed: page.bHasSpecies)
                    checkBadge("Ap", passed: page.bHasAppearance)
                }
            }

            // Side-by-side prompts
            HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Method A (single-pass):")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjCoral)
                    Text(page.methodAPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Method B (two-pass):")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjLavender)
                    Text(page.methodBPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.sjGlassInk)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
    }

    // MARK: - A/B Image Comparison Grid

    private func abImageComparisonGrid(_ abResult: ABTestResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Text("Visual Comparison")
                .font(StoryJuicerTypography.uiBodyStrong)
                .foregroundStyle(Color.sjGlassInk)

            ForEach(abResult.perPage) { page in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Page \(page.pageNumber)")
                        .font(StoryJuicerTypography.uiBodyStrong)
                        .foregroundStyle(Color.sjGlassInk)

                    HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
                        // Method A image
                        VStack(spacing: 6) {
                            if let cgImage = abImagesA[page.pageNumber] {
                                Image(decorative: cgImage, scale: 1.0)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            } else if abImageTestRunning {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.sjMuted.opacity(0.1))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.sjMuted.opacity(0.1))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        Image(systemName: "xmark.circle")
                                            .foregroundStyle(Color.sjMuted)
                                    }
                            }
                            Text("Method A")
                                .font(StoryJuicerTypography.uiMetaStrong)
                                .foregroundStyle(Color.sjCoral)
                        }
                        .frame(maxWidth: .infinity)

                        // Method B image
                        VStack(spacing: 6) {
                            if let cgImage = abImagesB[page.pageNumber] {
                                Image(decorative: cgImage, scale: 1.0)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            } else if abImageTestRunning {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.sjMuted.opacity(0.1))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.sjMuted.opacity(0.1))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        Image(systemName: "xmark.circle")
                                            .foregroundStyle(Color.sjMuted)
                                    }
                            }
                            Text("Method B")
                                .font(StoryJuicerTypography.uiMetaStrong)
                                .foregroundStyle(Color.sjLavender)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(StoryJuicerGlassTokens.Spacing.medium)
                .sjGlassCard(cornerRadius: StoryJuicerGlassTokens.Radius.card)
            }
        }
    }

    // MARK: - Test Execution: A/B Image Generation

    private func runABImageTest() {
        guard let abTestResult, let result else { return }
        abImageTestRunning = true
        abImagesA = [:]
        abImagesB = [:]
        abImageTotal = abTestResult.perPage.count * 2
        abImageCompleted = 0
        statusText = "Generating A/B comparison images..."

        Task {
            let illustrator = IllustrationGenerator()

            // Character descriptions for enrichment
            let charDescA = result.rawBook.characterDescriptions
            let charDescB = abTestResult.methodBCharacterDescriptions

            for page in abTestResult.perPage {
                let enrichedA = IllustrationGenerator.enrichPromptWithCharacters(
                    page.methodAPrompt,
                    characterDescriptions: charDescA
                )
                let enrichedB = IllustrationGenerator.enrichPromptWithCharacters(
                    page.methodBPrompt,
                    characterDescriptions: charDescB
                )

                statusText = "Page \(page.pageNumber): generating A & B images..."

                // Generate A and B for this page concurrently
                await withTaskGroup(of: (String, Int, CGImage?).self) { group in
                    group.addTask {
                        let image = try? await illustrator.generateSingleImage(
                            prompt: enrichedA,
                            style: .illustration,
                            format: .standard,
                            pageIndex: page.pageNumber
                        )
                        return ("A", page.pageNumber, image)
                    }
                    group.addTask {
                        let image = try? await illustrator.generateSingleImage(
                            prompt: enrichedB,
                            style: .illustration,
                            format: .standard,
                            pageIndex: page.pageNumber
                        )
                        return ("B", page.pageNumber, image)
                    }

                    for await (method, pageNum, image) in group {
                        await MainActor.run {
                            if let image {
                                if method == "A" {
                                    abImagesA[pageNum] = image
                                } else {
                                    abImagesB[pageNum] = image
                                }
                            }
                            abImageCompleted += 1
                        }
                    }
                }
            }

            await MainActor.run {
                abImageTestRunning = false
                statusText = ""
            }
        }
    }

    // MARK: - Test Execution: A/B Test (Two-Pass)

    private func runABTest() {
        guard let result else { return }
        abTestRunning = true
        abTestResult = nil
        abImagesA = [:]
        abImagesB = [:]
        statusText = "A/B Test: Pass 1 — generating text..."

        Task {
            do {
                // Method A scores already exist from the LLM test
                let methodAScores = ABTestResult.MethodScores(
                    overall: result.overallScore,
                    species: result.speciesInPromptsScore,
                    appearance: result.appearanceInPromptsScore,
                    name: result.nameConsistencyScore,
                    verdict: result.overallScore >= 0.75 ? "pass" : result.overallScore >= 0.50 ? "marginal" : "fail"
                )

                // Method B: Two-pass generation using Foundation Models
                let methodBBook = try await generateTwoPassStory()

                statusText = "A/B Test: Scoring method B..."

                let methodBResult = ImagePromptEnricher.evaluate(
                    rawBook: methodBBook,
                    expectedSpecies: expectedSpecies,
                    concept: baselineConcept
                )

                let methodBScores = ABTestResult.MethodScores(
                    overall: methodBResult.overallScore,
                    species: methodBResult.speciesInPromptsScore,
                    appearance: methodBResult.appearanceInPromptsScore,
                    name: methodBResult.nameConsistencyScore,
                    verdict: methodBResult.overallScore >= 0.75 ? "pass" : methodBResult.overallScore >= 0.50 ? "marginal" : "fail"
                )

                // Build per-page comparison
                var perPage: [ABTestResult.PageComparison] = []
                let methodAPages = result.details
                let methodBPages = methodBResult.details

                for (aPage, bPage) in zip(methodAPages, methodBPages) {
                    perPage.append(ABTestResult.PageComparison(
                        pageNumber: aPage.pageNumber,
                        methodAPrompt: aPage.rawImagePrompt,
                        methodBPrompt: bPage.rawImagePrompt,
                        aHasSpecies: aPage.hasSpecies,
                        bHasSpecies: bPage.hasSpecies,
                        aHasAppearance: aPage.hasAppearance,
                        bHasAppearance: bPage.hasAppearance
                    ))
                }

                await MainActor.run {
                    abTestResult = ABTestResult(
                        methodA: methodAScores,
                        methodB: methodBScores,
                        methodBCharacterDescriptions: methodBBook.characterDescriptions,
                        perPage: perPage
                    )
                    abTestRunning = false
                    statusText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = "A/B Test failed: \(error.localizedDescription)"
                    abTestRunning = false
                    statusText = ""
                }
            }
        }
    }

    /// Two-pass story generation: text first, then image prompts.
    @MainActor
    private func generateTwoPassStory() async throws -> StoryBook {
        guard SystemLanguageModel.default.availability == .available else {
            throw TestHarnessError.providerUnavailable
        }

        let safeConcept = ContentSafetyPolicy.sanitizeConcept(baselineConcept)
        let options = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: GenerationConfig.maximumResponseTokens(for: testPageCount)
        )

        // Pass 1: Generate text only
        statusText = "A/B Test: Pass 1 — generating story text..."
        let textSession = LanguageModelSession(
            instructions: StoryPromptTemplates.systemInstructions
        )
        let textPrompt = StoryPromptTemplates.textOnlyPrompt(
            concept: safeConcept,
            pageCount: testPageCount
        )
        let textResponse = try await textSession.respond(
            to: textPrompt,
            generating: TextOnlyStoryBook.self,
            options: options
        )
        let textBook = textResponse.content

        // Pass 2: Generate image prompts with full context
        statusText = "A/B Test: Pass 2 — generating image prompts..."
        let imageSession = LanguageModelSession(
            instructions: "You are an expert art director for children's storybook illustrations. Write vivid, detailed scene descriptions."
        )
        let imagePromptText = StoryPromptTemplates.imagePromptPassPrompt(
            characterDescriptions: textBook.characterDescriptions,
            pages: textBook.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        )
        let imageResponse = try await imageSession.respond(
            to: imagePromptText,
            generating: ImagePromptSheet.self,
            options: options
        )
        let promptSheet = imageResponse.content

        // Merge into a StoryBook
        let mergedPages = textBook.pages.map { textPage -> StoryPage in
            let matchingPrompt = promptSheet.prompts.first { $0.pageNumber == textPage.pageNumber }
            return StoryPage(
                pageNumber: textPage.pageNumber,
                text: textPage.text,
                imagePrompt: matchingPrompt?.imagePrompt ?? "A scene from a children's storybook"
            )
        }

        return StoryBook(
            title: textBook.title,
            authorLine: textBook.authorLine,
            moral: textBook.moral,
            characterDescriptions: textBook.characterDescriptions,
            pages: mergedPages
        )
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

        // Parsing test (optional — Upgrade 1)
        var parsingTest: TestHarnessExport.ParsingTest?
        if let parsingTestResult {
            let toExport = { (entries: [ImagePromptEnricher.CharacterEntry]) in
                entries.map { e in
                    TestHarnessExport.ParsingTest.CharacterEntryExport(
                        name: e.name,
                        species: e.species,
                        visualSummary: e.visualSummary,
                        injectionPhrase: e.injectionPhrase
                    )
                }
            }
            parsingTest = TestHarnessExport.ParsingTest(
                foundationModelUsed: parsingTestResult.foundationModelUsed,
                validationRepaired: CharacterDescriptionValidator.lastRepairUsedFoundationModel,
                regexParsed: toExport(parsingTestResult.regexParsed),
                foundationModelParsed: toExport(parsingTestResult.foundationModelParsed)
            )
        }

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
                variantWins: imageTestVariantWins,
                referenceImageEnabled: useReferenceImage
            )
        }

        // A/B test (optional)
        var abTest: TestHarnessExport.ABTest?
        if let abTestResult {
            let toScores = { (s: ABTestResult.MethodScores) in
                TestHarnessExport.ABTest.MethodScores(
                    overall: s.overall, species: s.species,
                    appearance: s.appearance, name: s.name, verdict: s.verdict
                )
            }
            let pages = abTestResult.perPage.map { p in
                TestHarnessExport.ABTest.PageComparison(
                    pageNumber: p.pageNumber,
                    methodAPrompt: p.methodAPrompt,
                    methodBPrompt: p.methodBPrompt,
                    aHasSpecies: p.aHasSpecies,
                    bHasSpecies: p.bHasSpecies,
                    aHasAppearance: p.aHasAppearance,
                    bHasAppearance: p.bHasAppearance
                )
            }
            var imageResults: TestHarnessExport.ABTest.ImageResults?
            if !abImagesA.isEmpty || !abImagesB.isEmpty {
                imageResults = TestHarnessExport.ABTest.ImageResults(
                    methodASuccessCount: abImagesA.count,
                    methodBSuccessCount: abImagesB.count,
                    totalPerMethod: abTestResult.perPage.count
                )
            }

            abTest = TestHarnessExport.ABTest(
                methodA: toScores(abTestResult.methodA),
                methodB: toScores(abTestResult.methodB),
                methodBCharacterDescriptions: abTestResult.methodBCharacterDescriptions,
                perPage: pages,
                imageResults: imageResults
            )
        }

        let export = TestHarnessExport(
            metadata: metadata,
            llmTest: llmTest,
            parsingTest: parsingTest,
            promptTest: promptTest,
            analysisTest: analysisTest,
            imageTest: imageTest,
            abTest: abTest
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

struct ParsingTestResult {
    let characterDescriptions: String
    let regexParsed: [ImagePromptEnricher.CharacterEntry]
    let foundationModelParsed: [ImagePromptEnricher.CharacterEntry]
    let foundationModelUsed: Bool
}

struct ABTestResult {
    let methodA: MethodScores
    let methodB: MethodScores
    let methodBCharacterDescriptions: String
    let perPage: [PageComparison]

    struct MethodScores {
        let overall: Double
        let species: Double
        let appearance: Double
        let name: Double
        let verdict: String
    }

    struct PageComparison: Identifiable {
        var id: Int { pageNumber }
        let pageNumber: Int
        let methodAPrompt: String
        let methodBPrompt: String
        let aHasSpecies: Bool
        let bHasSpecies: Bool
        let aHasAppearance: Bool
        let bHasAppearance: Bool
    }
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
    let parsingTest: ParsingTest?
    let promptTest: PromptTest?
    let analysisTest: AnalysisTest?
    let imageTest: ImageTest?
    let abTest: ABTest?

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

    struct ParsingTest: Codable {
        let foundationModelUsed: Bool
        let validationRepaired: Bool
        let regexParsed: [CharacterEntryExport]
        let foundationModelParsed: [CharacterEntryExport]

        struct CharacterEntryExport: Codable {
            let name: String
            let species: String
            let visualSummary: String
            let injectionPhrase: String
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
        let referenceImageEnabled: Bool
    }

    struct ABTest: Codable {
        let methodA: MethodScores
        let methodB: MethodScores
        let methodBCharacterDescriptions: String
        let perPage: [PageComparison]
        let imageResults: ImageResults?

        struct MethodScores: Codable {
            let overall: Double
            let species: Double
            let appearance: Double
            let name: Double
            let verdict: String
        }

        struct PageComparison: Codable {
            let pageNumber: Int
            let methodAPrompt: String
            let methodBPrompt: String
            let aHasSpecies: Bool
            let bHasSpecies: Bool
            let aHasAppearance: Bool
            let bHasAppearance: Bool
        }

        struct ImageResults: Codable {
            let methodASuccessCount: Int
            let methodBSuccessCount: Int
            let totalPerMethod: Int
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout for concept chips)

/// A simple wrapping horizontal layout that flows children into rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            if i > 0 { y += spacing }
            var x = bounds.minX
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(i)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
#endif
