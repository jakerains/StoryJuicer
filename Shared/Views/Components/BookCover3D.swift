import SwiftUI
import CoreGraphics

struct BookCover3D: View {
    let image: CGImage
    let title: String
    let authorLine: String
    let cornerRadius: CGFloat
    let isInteractive: Bool
    let isHovered: Bool
    let hoverVector: CGSize
    let showsTextOverlay: Bool

    private var effectiveHover: Bool {
        isInteractive && isHovered
    }

    private var yaw: Double {
        guard effectiveHover else { return StoryJuicerGlassTokens.Cover3D.idleYaw }
        let centeredYaw = (StoryJuicerGlassTokens.Cover3D.hoverYaw + StoryJuicerGlassTokens.Cover3D.idleYaw) / 2
        return centeredYaw + Double(hoverVector.width) * 1.2
    }

    private var pitch: Double {
        guard effectiveHover else { return StoryJuicerGlassTokens.Cover3D.idlePitch }
        let centeredPitch = (StoryJuicerGlassTokens.Cover3D.hoverPitch + StoryJuicerGlassTokens.Cover3D.idlePitch) / 2
        return centeredPitch + Double(-hoverVector.height) * 0.75
    }

    private var scale: CGFloat {
        effectiveHover ? StoryJuicerGlassTokens.Cover3D.hoverScale : 1
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalInset: CGFloat = showsTextOverlay ? 18 : 8
            let availableWidth = max(size.width - (horizontalInset * 2), 80)
            let spineWidth = clamped(
                availableWidth * StoryJuicerGlassTokens.Cover3D.spineWidthRatio,
                min: StoryJuicerGlassTokens.Cover3D.spineMinWidth,
                max: StoryJuicerGlassTokens.Cover3D.spineMaxWidth
            )
            let pageEdgeWidth = clamped(
                availableWidth * StoryJuicerGlassTokens.Cover3D.pageEdgeWidthRatio,
                min: StoryJuicerGlassTokens.Cover3D.pageEdgeMinWidth,
                max: StoryJuicerGlassTokens.Cover3D.pageEdgeMaxWidth
            )
            let frontCoverWidth = max(availableWidth, 60)

            HStack {
                Spacer(minLength: 0)
                bookShell(
                    frontCoverWidth: frontCoverWidth,
                    spineWidth: spineWidth,
                    pageEdgeWidth: pageEdgeWidth,
                    height: size.height
                )
                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height)
        }
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: hoverVector)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: effectiveHover)
    }

    private func bookShell(
        frontCoverWidth: CGFloat,
        spineWidth: CGFloat,
        pageEdgeWidth: CGFloat,
        height: CGFloat
    ) -> some View {
        frontCoverView
            .frame(width: frontCoverWidth, height: height)
            .overlay(alignment: .leading) {
                spineView
                    .frame(width: spineWidth, height: height)
            }
            .overlay(alignment: .trailing) {
                pageBlockView
                    .frame(width: pageEdgeWidth, height: height)
            }
        .rotation3DEffect(
            .degrees(pitch),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: StoryJuicerGlassTokens.Cover3D.perspective
        )
        .rotation3DEffect(
            .degrees(yaw),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: StoryJuicerGlassTokens.Cover3D.perspective
        )
        .scaleEffect(scale)
        .shadow(
            color: .black.opacity(effectiveHover ? 0.34 : 0.22),
            radius: effectiveHover ? 26 : 18,
            y: effectiveHover ? 14 : 10
        )
        .shadow(
            color: Color.sjGold.opacity(effectiveHover ? 0.12 : 0.07),
            radius: effectiveHover ? 8 : 5,
            y: 2
        )
    }

    private var spineView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.56),
                    Color.sjText.opacity(0.58),
                    Color.sjSecondaryText.opacity(0.36)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [
                    .white.opacity(0.18),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(.black.opacity(0.12))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var frontCoverView: some View {
        ZStack {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .scaledToFill()

            if showsTextOverlay {
                coverTextOverlay
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay {
            if showsTextOverlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 4, 4))
                    .strokeBorder(Color.sjGold.opacity(0.38), lineWidth: 1.5)
                    .padding(14)
            } else {
                RoundedRectangle(cornerRadius: max(cornerRadius - 2, 2))
                    .strokeBorder(Color.sjGold.opacity(0.18), lineWidth: 0.8)
                    .padding(6)
            }
        }
    }

    private var pageBlockView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.sjPaperTop.opacity(0.96),
                    Color.sjPaperBottom.opacity(0.92),
                    Color.sjBackground.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { _ in
                    Rectangle()
                        .fill(.black.opacity(0.12))
                        .frame(height: 0.6)
                }
            }
            .padding(.vertical, 6)
            .opacity(0.4)

            Rectangle()
                .fill(.black.opacity(0.1))
                .frame(width: 0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            LinearGradient(
                colors: [.white.opacity(0.2), .clear],
                startPoint: .trailing,
                endPoint: .leading
            )
        }
    }

    private var coverTextOverlay: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Spacer()

            Text(title)
                .font(.system(size: 44, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.8), radius: 1, y: 2)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            Text(authorLine)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .italic()
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 40)
    }

    private func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
