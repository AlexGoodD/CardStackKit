//
//  CardStack.swift
//  CardStackKit
//
//  Created by Alejandro Chavarria on 09/03/26.
//

import SwiftUI

/// The main view of CardStackKit.
///
/// Renders a collection of items as a stack of layered cards,
/// with support for vertical and horizontal scrolling, configurable snap,
/// and a modifier-based API consistent with SwiftUI conventions.
///
/// ## Basic usage
/// ```swift
/// CardStack(items: myCards, axis: .vertical, itemSize: 220) { card, ctx in
///     MyCardView(card: card)
///         .frame(width: ctx.crossAxisSize, height: 220)
///         .position(x: ctx.crossAxisPosition, y: ctx.mainAxisPosition + 110)
///         .zIndex(ctx.zIndex)
/// }
/// .pendingVisible(5)
/// .spacing(min: 24, max: 60)
/// .activeAnchor(.center)
/// ```
///
/// ## Positioning
/// Each card receives a ``CardStackItemContext`` with `mainAxisPosition` and
/// `crossAxisPosition`. Apply them using `.position(x:y:)` so the card appears
/// where the stack expects it. `mainAxisPosition` is the leading edge of the card,
/// so add `itemSize / 2` to center it correctly with `.position()`.
///
/// **Vertical axis**
/// ```swift
/// .position(x: ctx.crossAxisPosition, y: ctx.mainAxisPosition + itemSize / 2)
/// ```
/// **Horizontal axis**
/// ```swift
/// .position(x: ctx.mainAxisPosition + itemSize / 2, y: ctx.crossAxisPosition)
/// ```
///
/// - Note: Requires iOS 17+ due to `@Observable` usage in ``CardStackEngine``.
public struct CardStack<Data, Content>: View
where Data: RandomAccessCollection,
      Data.Index == Int,
      Content: View {

    // MARK: - Properties

    private let data: Data
    private let axis: CardStackAxis
    private let itemSize: CGFloat
    private let content: (Data.Element, CardStackItemContext) -> Content
    private var config: CardStackConfig

    /// State engine. Stored in @State to survive SwiftUI re-renders.
    @State private var engine: CardStackEngine

    // MARK: - Init

    /// Creates the card stack.
    /// - Parameters:
    ///   - items: Data collection to render. Must be `RandomAccessCollection` with `Int` index.
    ///   - axis: Scroll axis. Defaults to `.vertical`.
    ///   - itemSize: Item size along the main axis (height for vertical, width for horizontal).
    ///   - config: Full behavior configuration. Defaults to ``CardStackConfig/init()``.
    ///   - content: ViewBuilder receiving each element and its ``CardStackItemContext``.
    public init(
        items: Data,
        axis: CardStackAxis = .vertical,
        itemSize: CGFloat,
        config: CardStackConfig = .init(),
        @ViewBuilder content: @escaping (Data.Element, CardStackItemContext) -> Content
    ) {
        self.data = items
        self.axis = axis
        self.itemSize = itemSize
        self.content = content
        self.config = config
        self._engine = State(initialValue: CardStackEngine(
            totalItems: items.count,
            itemSize: itemSize,
            config: config
        ))
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            // CardStackGeometry is stateless — instantiated fresh every render.
            // Receives the real container size to compute positions.
            let geometry = CardStackGeometry(
                config: config,
                containerSize: geo.size,
                axis: axis,
                itemSize: itemSize
            )
            let spacing = geometry.effectiveSpacing(arrived: engine.arrivedCount)
            let origin  = geometry.stackOrigin(arrived: engine.arrivedCount, spacing: spacing)
            let nextIdx = engine.nextIndex

            ZStack {
                // Transparent background with contentShape to guarantee a hit area
                // across the full container, even where no cards are present.
                Color.clear.contentShape(Rectangle())

                ForEach(0..<data.count, id: \.self) { index in
                    let p       = engine.progress(for: index)
                    let dest    = geometry.destPosition(index: index, spacing: spacing, origin: origin)
                    let stack   = geometry.pendingPosition(
                                      index: index,
                                      nextIndex: nextIdx,
                                      arrived: engine.arrivedCount,
                                      spacing: spacing
                                  )
                    let current = geometry.currentPosition(destPos: dest, stackPos: stack, progress: p)

                    let ctx = CardStackItemContext(
                        index: index,
                        progress: p,
                        isActive: index == nextIdx - 1,
                        isPending: p < 1,
                        mainAxisPosition: current,
                        crossAxisPosition: geometry.crossAxisCenter,
                        crossAxisSize: geometry.itemCrossAxisSize,
                        zIndex: Double(index)
                    )

                    content(data[index], ctx)
                }
            }
            // Two separate animation values:
            // liveOffset → animates card movement during drag
            // spacing    → animates spacing compression as cards arrive
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: engine.liveOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: spacing)
            // highPriorityGesture ensures the stack drag takes precedence over
            // parent container gestures (e.g. NavigationStack swipe-back).
            .highPriorityGesture(dragGesture)
            // Syncs the engine when the collection changes at runtime
            // (pagination, filtering, insertions). Clamps the offset so it
            // doesn't point to an index that no longer exists.
            .onChange(of: data.count) { _, newCount in
                let maxOffset = CGFloat(max(newCount - 1, 0)) * itemSize
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    engine.committedOffset = min(engine.committedOffset, maxOffset)
                    engine.dragDelta = 0
                }
            }
        }
    }

    // MARK: - Gesture

    /// Drag gesture that feeds the engine.
    ///
    /// Reads the translation component for the configured axis and passes it
    /// to the engine. The engine is the sole authority on how to apply it.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // Vertical:   drag up   (negative height) → advance → invert
                // Horizontal: drag left (negative width)  → advance → invert
                let translation = axis == .vertical
                    ? value.translation.height
                    : value.translation.width
                engine.onDragChanged(translation: translation)
            }
            .onEnded { value in
                let translation = axis == .vertical
                    ? value.translation.height
                    : value.translation.width
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    engine.onDragEnded(translation: translation)
                }
            }
    }
}

// MARK: - Modifiers
//
// Each modifier returns a copy of CardStack with a mutated config,
// following the SwiftUI fluent modifier pattern (.foregroundColor, .padding, etc.).
//
// To add a new modifier:
// 1. Add the corresponding property to CardStackConfig.
// 2. Add a function here that mutates config on a copy of self.

extension CardStack {

    /// Number of pending cards rendered and visible in the bottom pile.
    ///
    /// Cards beyond this limit are not added to the view hierarchy.
    /// - Parameter count: Number of visible pending cards. Default: `5`.
    public func pendingVisible(_ count: Int) -> CardStack {
        var copy = self; copy.config.pendingVisible = count; return copy
    }

    /// Spacing between cards in the top stack.
    ///
    /// The actual spacing compresses dynamically between these bounds as more
    /// cards arrive. See ``CardStackGeometry/effectiveSpacing(arrived:)``.
    /// - Parameters:
    ///   - min: Minimum spacing in points. Prevents full overlap.
    ///   - max: Maximum spacing in points. Used when few cards have arrived.
    public func spacing(min: CGFloat, max: CGFloat) -> CardStack {
        var copy = self; copy.config.minSpacing = min; copy.config.maxSpacing = max; return copy
    }

    /// Spacing between cards in the pending pile.
    ///
    /// Controls how much each card peeks out from behind the one in front.
    /// - Parameter value: Spacing in points. Default: `10`.
    public func pendingPeek(_ value: CGFloat) -> CardStack {
        var copy = self; copy.config.pendingPeek = value; return copy
    }

    /// Minimum space reserved to keep the pending pile always visible.
    ///
    /// Ensures the top stack never grows into the area where the pending pile
    /// should remain visible.
    /// - Parameter value: Space in points. Default: `80`.
    public func minPendingVisible(_ value: CGFloat) -> CardStack {
        var copy = self; copy.config.minPendingVisible = value; return copy
    }

    /// Controls how far the active card can travel along the main axis.
    ///
    /// - `.top`: Active card stays at `topPadding`.
    /// - `.center`: Active card never goes past the center of the container.
    /// - `.free`: No restriction.
    /// - Parameter anchor: Desired behavior. Default: `.center`.
    public func activeAnchor(_ anchor: CardStackConfig.ActiveAnchor) -> CardStack {
        var copy = self; copy.config.activeAnchor = anchor; return copy
    }

    /// Snap behavior when the drag gesture ends.
    ///
    /// - `.perCard`: Snaps to the nearest card boundary.
    /// - `.free`: Offset stays wherever the gesture left it.
    /// - Parameter behavior: Desired behavior. Default: `.perCard`.
    public func snapBehavior(_ behavior: CardStackConfig.SnapBehavior) -> CardStack {
        var copy = self; copy.config.snapBehavior = behavior; return copy
    }

    /// Internal padding between the stack and the container edges.
    /// - Parameters:
    ///   - top: Space from the top edge. Default: `40`.
    ///   - bottom: Space from the bottom edge. Default: `40`.
    ///   - leading: Space from the leading edge. Default: `24`.
    ///   - trailing: Space from the trailing edge. Default: `24`.
    public func stackPadding(
        top: CGFloat = 40, bottom: CGFloat = 40,
        leading: CGFloat = 24, trailing: CGFloat = 24
    ) -> CardStack {
        var copy = self
        copy.config.topPadding      = top
        copy.config.bottomPadding   = bottom
        copy.config.leadingPadding  = leading
        copy.config.trailingPadding = trailing
        return copy
    }
}
