import SwiftUI

/// Direction of a page turn animation.
enum PageTurnDirection {
    case forward   // page folds from trailing edge
    case backward  // page folds from leading edge
}

/// Manages the lifecycle of a single page turn animation.
///
/// Separates animation state from ``BookReaderViewModel`` so the reader view can
/// composite both the current and destination pages during the turn without
/// the view model's `currentPage` changing mid-animation.
@Observable
@MainActor
final class PageTurnState {
    var turnProgress: CGFloat = 0
    var isTurning: Bool = false
    var turnDirection: PageTurnDirection = .forward
    var fromPage: Int = 0
    var toPage: Int = 0

    /// Called when the turn animation finishes. The view wires this up
    /// to commit the page change on the view model.
    var onTurnComplete: (() -> Void)?

    /// Start a page turn animation from one page index to another.
    func beginTurn(from: Int, to: Int, direction: PageTurnDirection) {
        guard !isTurning else { return }
        fromPage = from
        toPage = to
        turnDirection = direction
        isTurning = true
        turnProgress = 0

        withAnimation(StoryJuicerMotion.pageTurn) {
            turnProgress = 1.0
        } completion: { [weak self] in
            self?.completeTurn()
        }
    }

    /// Reset state after the animation completes.
    /// Uses an explicit nil-animation transaction to prevent Animatable
    /// from interpolating the progress reset (1.0 → 0.0).
    private func completeTurn() {
        onTurnComplete?()
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            isTurning = false
            turnProgress = 0
        }
    }
}
