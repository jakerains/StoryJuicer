import SwiftUI

extension View {
    @ViewBuilder
    func sjGlassCard(
        tint: Color = .clear,
        interactive: Bool = false,
        cornerRadius: CGFloat = StoryJuicerGlassTokens.Radius.card
    ) -> some View {
        if interactive {
            self.glassEffect(
                .regular.tint(tint).interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.glassEffect(
                .regular.tint(tint),
                in: .rect(cornerRadius: cornerRadius)
            )
        }
    }

    func sjGlassChip(
        selected: Bool,
        interactive: Bool = true
    ) -> some View {
        sjGlassCard(
            tint: selected ? .sjCoral.opacity(StoryJuicerGlassTokens.Tint.standard) : .sjGlassWeak,
            interactive: interactive,
            cornerRadius: StoryJuicerGlassTokens.Radius.chip
        )
    }

    @ViewBuilder
    func sjGlassToolbarItem(prominent: Bool) -> some View {
        if prominent {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.glass)
        }
    }
}
