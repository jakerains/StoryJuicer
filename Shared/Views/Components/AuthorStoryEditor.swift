import SwiftUI

/// Page-by-page editor for Author Mode.
/// Users write their own story title, optional character descriptions,
/// and page text — StoryFox then generates illustrations.
struct AuthorStoryEditor: View {
    @Bindable var viewModel: CreationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            // Title field
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Text("Story Title")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjGlassInk)

                TextField("The Adventures of...", text: $viewModel.authorTitle)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjText)
                    .textFieldStyle(.plain)
                    .padding(StoryJuicerGlassTokens.Spacing.small)
                    .background(Color.sjReadableCard.opacity(0.9))
                    .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
                    .overlay {
                        RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                            .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
                    }
            }

            // Character descriptions (optional)
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                    Text("Character Descriptions")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjGlassInk)

                    Text("(optional)")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }

                TextEditor(text: $viewModel.authorCharacterDescriptions)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjText)
                    .frame(minHeight: 50, maxHeight: 80)
                    .padding(StoryJuicerGlassTokens.Spacing.small)
                    .scrollContentBackground(.hidden)
                    .background(Color.sjReadableCard.opacity(0.9))
                    .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
                    .overlay {
                        RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                            .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
                    }
                    .overlay(alignment: .topLeading) {
                        if viewModel.authorCharacterDescriptions.isEmpty {
                            Text("e.g. Luna - small orange fox, green scarf, curious eyes")
                                .font(StoryJuicerTypography.uiBody)
                                .foregroundStyle(Color.sjSecondaryText)
                                .padding(StoryJuicerGlassTokens.Spacing.medium)
                                .allowsHitTesting(false)
                        }
                    }
            }

            // Page editors
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                HStack {
                    Text("Pages")
                        .font(StoryJuicerTypography.uiMetaStrong)
                        .foregroundStyle(Color.sjGlassInk)

                    Spacer()

                    pageCountControls
                }

                ForEach(viewModel.authorPages.indices, id: \.self) { index in
                    pageEditor(index: index)
                }
            }
        }
    }

    // MARK: - Page Count Controls

    private var pageCountControls: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Button {
                withAnimation(StoryJuicerMotion.fast) {
                    guard viewModel.authorPages.count > 1 else { return }
                    viewModel.authorPages.removeLast()
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        viewModel.authorPages.count > 1 ? Color.sjCoral : Color.sjMuted
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.authorPages.count <= 1)

            Text("\(viewModel.authorPages.count) pages")
                .font(StoryJuicerTypography.uiMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .monospacedDigit()

            Button {
                withAnimation(StoryJuicerMotion.fast) {
                    guard viewModel.authorPages.count < GenerationConfig.maxPages else { return }
                    viewModel.authorPages.append("")
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        viewModel.authorPages.count < GenerationConfig.maxPages ? Color.sjCoral : Color.sjMuted
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.authorPages.count >= GenerationConfig.maxPages)
        }
    }

    // MARK: - Individual Page Editor

    private func pageEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Text("Page \(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.sjCoral.opacity(0.8))

            TextEditor(text: $viewModel.authorPages[index])
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjText)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(StoryJuicerGlassTokens.Spacing.small)
                .scrollContentBackground(.hidden)
                .background(Color.sjReadableCard.opacity(0.9))
                .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
                .overlay {
                    RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                        .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if viewModel.authorPages[index].isEmpty {
                        Text("Write page \(index + 1) of your story...")
                            .font(StoryJuicerTypography.uiBody)
                            .foregroundStyle(Color.sjSecondaryText)
                            .padding(StoryJuicerGlassTokens.Spacing.medium)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
