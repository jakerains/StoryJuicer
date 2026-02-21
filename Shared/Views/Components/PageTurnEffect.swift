import SwiftUI

/// A view that composites two pages and animates a 3D page turn between them.
///
/// **Forward**: the current page (front) lifts away from the leading edge,
/// revealing the destination page (back) underneath.
///
/// **Backward**: the destination page (back) folds in from the leading edge,
/// covering the current page (front) underneath — the visual reverse of a
/// forward turn.
///
/// `.drawingGroup()` rasterizes each page layer into a Metal texture before
/// applying `rotation3DEffect`, which is critical for smooth animation when
/// pages contain large CGImages.
struct PageTurnView<Front: View, Back: View>: View, Animatable {
    let frontPage: Front
    let backPage: Back
    var progress: CGFloat
    let direction: PageTurnDirection

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Whether we've passed the midpoint and should swap front/back face.
    private var isPastHalf: Bool { progress > 0.5 }

    var body: some View {
        ZStack {
            if direction == .forward {
                forwardTurn
            } else {
                backwardTurn
            }
        }
    }

    // MARK: - Forward Turn

    /// Current page lifts off to the left, revealing destination underneath.
    private var forwardTurn: some View {
        let angle = -Double(progress) * 180  // 0° → -180°

        return ZStack {
            // Stationary destination page (revealed as current lifts)
            backPage
                .drawingGroup()
                .overlay {
                    Color.black
                        .opacity(0.25 * Double(1.0 - progress))
                        .allowsHitTesting(false)
                }

            // Turning current page
            if !isPastHalf {
                // First half: front face of current page rotating away
                frontPage
                    .drawingGroup()
                    .rotation3DEffect(
                        .degrees(angle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
                    .shadow(
                        color: .black.opacity(0.15 * Double(progress)),
                        radius: 12 * Double(progress),
                        x: -8 * Double(progress)
                    )
            } else {
                // Second half: back face shows destination content
                backPage
                    .drawingGroup()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(
                        .degrees(angle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
                    .shadow(
                        color: .black.opacity(0.15 * Double(1.0 - progress)),
                        radius: 12 * Double(1.0 - progress),
                        x: 8 * Double(1.0 - progress)
                    )
            }
        }
    }

    // MARK: - Backward Turn

    /// Destination page folds in from the left, covering current page.
    private var backwardTurn: some View {
        // Angle goes from -180° (folded behind) to 0° (flat)
        let angle = -180.0 * Double(1.0 - progress)

        return ZStack {
            // Stationary current page (gets covered by incoming page)
            frontPage
                .drawingGroup()
                .overlay {
                    Color.black
                        .opacity(0.25 * Double(progress))
                        .allowsHitTesting(false)
                }

            // Turning destination page (folding in from the left)
            if isPastHalf {
                // Second half: front face of incoming page settling flat
                backPage
                    .drawingGroup()
                    .rotation3DEffect(
                        .degrees(angle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
                    .shadow(
                        color: .black.opacity(0.15 * Double(1.0 - progress)),
                        radius: 12 * Double(1.0 - progress),
                        x: 8 * Double(1.0 - progress)
                    )
            } else {
                // First half: back face of incoming page (still mostly folded)
                frontPage
                    .drawingGroup()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(
                        .degrees(angle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.4
                    )
                    .shadow(
                        color: .black.opacity(0.15 * Double(progress)),
                        radius: 12 * Double(progress),
                        x: -8 * Double(progress)
                    )
            }
        }
    }
}
