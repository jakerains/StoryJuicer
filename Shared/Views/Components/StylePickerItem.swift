import SwiftUI

struct StylePickerItem: View {
    let style: IllustrationStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Image(systemName: style.iconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(isSelected ? Color.sjCoral : Color.sjSecondaryText)
                .frame(width: 46, height: 46)
                .sjGlassChip(selected: isSelected, interactive: true)

            Text(style.displayName)
                .font(.system(.callout, design: .rounded).weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.sjCoral : Color.sjText)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .animation(StoryJuicerMotion.standard, value: isSelected)
    }
}
