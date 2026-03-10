//
//  CardStackEngine.swift
//  CardStackKit
//
//  Created by Alejandro Chavarria on 09/03/26.
//

import SwiftUI
import Observation

/// State engine for ``CardStack``.
///
/// Manages the scroll offset and exposes derived properties that
/// ``CardStackGeometry`` and ``CardStack`` use to calculate positions
/// and determine which cards to render.
///
/// Axis-agnostic, screen-size-agnostic, and independent of SwiftUI views.
/// All visual layout logic lives in ``CardStackGeometry``.
@Observable
public final class CardStackEngine {

    // MARK: - Mutable State
    //
    // committedOffset: saved offset between gestures (updated on drag end).
    // dragDelta:       live delta while the finger is on screen.
    // liveOffset = committedOffset + dragDelta → actual position each frame.

    /// Accumulated offset confirmed between gestures.
    /// Updated in `onDragEnded` after snap or free settle is applied.
    public var committedOffset: CGFloat = 0

    /// Live delta of the active gesture. Reset to `0` when the gesture ends.
    /// Kept separate from `committedOffset` so rubber-band effects or clamping
    /// can be applied without corrupting the base offset.
    public var dragDelta: CGFloat = 0

    // MARK: - Immutable Config
    //
    // Stored as separate properties (not just inside config) so the engine
    // can compute maxOffset and progress without depending on the full struct.

    /// Total number of items in the stack.
    public let totalItems: Int

    /// Size of each item along the main axis (height for vertical, width for horizontal).
    /// Defines how much offset corresponds to "one card".
    public let itemSize: CGFloat

    /// Full stack configuration. The engine reads `snapBehavior` and `pendingVisible`.
    public let config: CardStackConfig

    // MARK: - Init

    /// Creates the stack engine.
    /// - Parameters:
    ///   - totalItems: Total number of cards in the stack.
    ///   - itemSize: Height (vertical) or width (horizontal) of each card in points.
    ///   - config: Behavior configuration. Defaults to ``CardStackConfig/init()``.
    public init(totalItems: Int, itemSize: CGFloat, config: CardStackConfig = .init()) {
        self.totalItems = totalItems
        self.itemSize = itemSize
        self.config = config
    }

    // MARK: - Derived: Offset

    /// Maximum reachable offset. Equivalent to having the last card active.
    public var maxOffset: CGFloat {
        CGFloat(totalItems - 1) * itemSize
    }

    /// Live offset combining committed offset and the active gesture delta.
    /// Always clamped to `[0, maxOffset]`.
    public var liveOffset: CGFloat {
        min(maxOffset, max(0, committedOffset + dragDelta))
    }

    // MARK: - Derived: Card State

    /// Number of cards that have fully arrived at their top-stack position (`progress == 1`).
    /// Always starts at `1` since card at index `0` is always arrived.
    public var arrivedCount: CGFloat {
        CGFloat(Int(liveOffset / itemSize)) + 1
    }

    /// Index of the next card to move up from the pending pile.
    /// Never exceeds `totalItems - 1`.
    public var nextIndex: Int {
        min(Int(liveOffset / itemSize) + 1, totalItems - 1)
    }

    /// Movement progress of an individual card.
    ///
    /// - Returns: `0.0` when the card is fully in the pending pile,
    ///            `1.0` when it has reached its final position in the top stack,
    ///            an intermediate value while transitioning.
    /// - Note: The card at index `0` always returns `1.0` — it starts at the top.
    public func progress(for index: Int) -> CGFloat {
        guard index > 0 else { return 1 }
        let cf = CGFloat(index)
        return min(1, max(0, (liveOffset - (cf - 1) * itemSize) / itemSize))
    }

    /// Whether a card should be included in the view hierarchy.
    ///
    /// Cards that have already arrived are always visible.
    /// Pending cards are only rendered if their queue position is within
    /// `config.pendingVisible`, avoiding unnecessary view nodes.
    ///
    /// - Parameter index: Index of the card to evaluate.
    /// - Returns: `true` if the card should be rendered.
    public func isVisible(index: Int) -> Bool {
        let p = progress(for: index)
        guard p < 1 else { return true }
        let queuePos = index - nextIndex
        return queuePos < config.pendingVisible
    }

    // MARK: - Gesture Handlers
    //
    // Designed to be called from any gesture or input type.
    // CardStack calls these from DragGesture, but they could be connected
    // to scroll wheel, keyboard, or accessibility actions without changing the engine.

    /// Updates the live delta while a gesture is active.
    /// - Parameter translation: Gesture displacement along the main axis.
    ///   Positive = down/right, negative = up/left.
    public func onDragChanged(translation: CGFloat) {
        dragDelta = -translation
    }

    /// Commits the offset and applies snap when the gesture ends.
    /// - Parameter translation: Final gesture displacement along the main axis.
    ///
    /// Behavior depends on `config.snapBehavior`:
    /// - `.perCard`: snaps to the nearest card boundary using `.rounded()`.
    /// - `.free`: freezes the offset wherever the gesture left it.
    public func onDragEnded(translation: CGFloat) {
        switch config.snapBehavior {
        case .perCard:
            let raw     = committedOffset - translation
            let snapped = (raw / itemSize).rounded() * itemSize
            committedOffset = min(maxOffset, max(0, snapped))
            dragDelta = 0
        case .free:
            committedOffset = liveOffset
            dragDelta = 0
        }
    }
}
