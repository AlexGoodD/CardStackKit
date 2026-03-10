//
//  CardStackItemContext.swift
//  CardStackKit
//
//  Created by Alejandro Chavarria on 09/03/26.
//

import CoreGraphics

/// Positioning and state context delivered by ``CardStack`` to each card view.
///
/// Received in the `content` closure. Apply `mainAxisPosition`,
/// `crossAxisPosition`, and `zIndex` to your view so it appears
/// where the stack expects it.
///
/// ## Usage example
/// ```swift
/// CardStack(items: cards, axis: .vertical, itemSize: 220) { card, ctx in
///     MyCardView(card: card)
///         .frame(width: ctx.crossAxisSize, height: 220)
///         // mainAxisPosition is the leading edge — add itemSize/2 to center with .position()
///         .position(x: ctx.crossAxisPosition, y: ctx.mainAxisPosition + 110)
///         .zIndex(ctx.zIndex)
///         .opacity(ctx.isPending ? 0.85 : 1)
/// }
/// ```
///
/// ## Horizontal axis
/// When using `.horizontal`, swap the x/y mapping:
/// ```swift
/// .frame(width: 220, height: ctx.crossAxisSize)
/// .position(x: ctx.mainAxisPosition + 110, y: ctx.crossAxisPosition)
/// ```
public struct CardStackItemContext {

    // MARK: - Identity

    /// Index of this card in the original data collection.
    ///
    /// Useful for applying position-based styles (e.g. always highlight the first card).
    public let index: Int

    // MARK: - Movement State

    /// Movement progress of the card between the pending pile and its final position.
    ///
    /// - `0.0`: fully in the pending pile, has not started moving yet.
    /// - `1.0`: has reached its final position in the top stack.
    /// - Intermediate value: in transition — useful for animating opacity, scale, etc.
    public let progress: CGFloat

    /// Whether this card is currently active — the last one to arrive in the top stack.
    ///
    /// Only one card has `isActive == true` at any given moment.
    /// Useful for visually highlighting the card in focus.
    public let isActive: Bool

    /// Whether the card has not yet moved to the top stack (`progress < 1`).
    ///
    /// Equivalent to `progress < 1`. Provided as a convenience for
    /// more readable style conditionals.
    public let isPending: Bool

    // MARK: - Position

    /// Position of the card's **leading edge** along the main axis.
    ///
    /// - Vertical axis: Y coordinate.
    /// - Horizontal axis: X coordinate.
    ///
    /// - Important: `.position(x:y:)` centers the view on the given point.
    ///   Add `itemSize / 2` to align the leading edge correctly.
    ///   Example: `.position(x: ctx.crossAxisPosition, y: ctx.mainAxisPosition + 110)`
    public let mainAxisPosition: CGFloat

    /// Center of the container along the cross axis.
    ///
    /// - Vertical axis: X coordinate (horizontal center of the container).
    /// - Horizontal axis: Y coordinate (vertical center of the container).
    ///
    /// Use directly with `.position()` to center cards on the cross axis.
    public let crossAxisPosition: CGFloat

    /// Available card size along the cross axis, after subtracting padding.
    ///
    /// - Vertical axis: available width (`containerWidth - leadingPadding - trailingPadding`).
    /// - Horizontal axis: available height (`containerHeight - topPadding - bottomPadding`).
    ///
    /// Use as `width` (vertical) or `height` (horizontal) in the card's `.frame()`.
    public let crossAxisSize: CGFloat

    // MARK: - Layering

    /// Computed `zIndex` value to maintain correct stacking order.
    ///
    /// Apply with `.zIndex(ctx.zIndex)` on the card view.
    public let zIndex: Double
}
