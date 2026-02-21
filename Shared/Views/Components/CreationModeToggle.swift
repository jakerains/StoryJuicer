import SwiftUI

struct CreationModeToggle: View {
    @Binding var selection: CreationMode

    @State private var hoveredMode: CreationMode?

    var body: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            ForEach(CreationMode.allCases) { mode in
                modeChip(mode)
            }
        }
        .overlay(alignment: .bottom) {
            if let mode = hoveredMode {
                hoverTooltip(for: mode)
                    .offset(y: 36)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }
        }
        .animation(.snappy(duration: 0.18), value: hoveredMode)
    }

    // MARK: - Chip

    private func modeChip(_ mode: CreationMode) -> some View {
        let isSelected = selection == mode

        return Button {
            withAnimation(StoryJuicerMotion.standard) {
                selection = mode
            }
        } label: {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.sjCoral : .sjSecondaryText)

                Text(mode.displayName)
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(isSelected ? Color.sjGlassInk : .sjSecondaryText)
            }
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
            .contentShape(Rectangle())
            .sjGlassChip(selected: isSelected, interactive: true)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredMode = hovering ? mode : nil
        }
        .accessibilityLabel("\(mode.displayName) creation mode — \(mode.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Tooltip

    private func hoverTooltip(for mode: CreationMode) -> some View {
        Text(mode.subtitle)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.sjGlassInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.sjBorder.opacity(0.5), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
    }
}
