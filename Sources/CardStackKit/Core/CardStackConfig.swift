//
//  CardStackConfig.swift
//  CardStackKit
//
//  Created by Alejandro Chavarria on 09/03/26.
//

import CoreGraphics

/// Configuration for the behavior and layout of a ``CardStack``.
///
/// All properties have sensible defaults and can be overridden either
/// by passing a custom `CardStackConfig` to the initializer, or by using
/// the fluent modifier API on ``CardStack``.
///
/// ```swift
/// CardStack(items: cards, itemSize: 220) { card, ctx in ... }
///     .spacing(min: 16, max: 48)
///     .activeAnchor(.center)
///     .snapBehavior(.perCard)
/// ```
public struct CardStackConfig {

    // MARK: - Spacing

    /// Maximum spacing between cards in the top stack.
    ///
    /// Used when only a few cards have arrived and there is plenty of room.
    /// Default: `60`.
    public var maxSpacing: CGFloat = 60

    /// Minimum spacing between cards in the top stack.
    ///
    /// Prevents cards from overlapping completely as the stack grows.
    /// Default: `24`.
    public var minSpacing: CGFloat = 24

    // MARK: - Pending stack

    /// Spacing between cards in the pending (bottom) pile.
    ///
    /// Controls how much each card peeks out from behind the one in front.
    /// Default: `10`.
    public var pendingPeek: CGFloat = 10

    /// Minimum space reserved for the pending pile to remain visible.
    ///
    /// Prevents the top stack from growing into the area where the pending
    /// pile should always be visible. Default: `80`.
    public var minPendingVisible: CGFloat = 80

    /// Number of pending cards rendered and visible in the bottom pile.
    ///
    /// Cards beyond this limit are still part of the data but are not
    /// added to the view hierarchy. Default: `5`.
    public var pendingVisible: Int = 5

    // MARK: - Padding

    /// Space between the top edge of the container and the first card. Default: `40`.
    public var topPadding: CGFloat = 40

    /// Space between the bottom edge of the container and the pending pile. Default: `40`.
    public var bottomPadding: CGFloat = 40

    /// Space between the leading edge of the container and the cards. Default: `24`.
    public var leadingPadding: CGFloat = 24

    /// Space between the trailing edge of the container and the cards. Default: `24`.
    public var trailingPadding: CGFloat = 24

    // MARK: - Active card anchor

    /// Controls how far the active card can travel along the main axis.
    ///
    /// Default: `.center`.
    public var activeAnchor: ActiveAnchor = .center

    /// Defines the maximum position the active card can reach.
    public enum ActiveAnchor {
        /// The active card stays at `topPadding` and never moves further down.
        case top
        /// The active card never goes past the center of the container.
        case center
        /// No restriction — the active card can reach any position.
        case free
    }

    // MARK: - Snap

    /// Defines the snap behavior when the drag gesture ends.
    ///
    /// Default: `.perCard`.
    public var snapBehavior: SnapBehavior = .perCard

    /// Defines how the stack settles after a drag gesture ends.
    public enum SnapBehavior {
        /// Snaps to the nearest card boundary when the gesture ends.
        case perCard
        /// No snap — the offset stays wherever the gesture left it.
        case free
    }

    // MARK: - Init

    /// Creates a `CardStackConfig` with default values.
    public init() {}
}
