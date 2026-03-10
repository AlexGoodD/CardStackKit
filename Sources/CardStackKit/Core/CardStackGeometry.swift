//
//  CardStackGeometry.swift
//  CardStackKit
//
//  Created by Alejandro Chavarria on 09/03/26.
//

import CoreGraphics

/// Position calculator for ``CardStack``.
///
/// A stateless struct that converts ``CardStackEngine`` values into
/// screen coordinates for each card.
/// All functions are pure and unit-testable without any views.
public struct CardStackGeometry {

    // MARK: - Properties

    /// Stack configuration (paddings, spacing, anchor, peek).
    public let config: CardStackConfig

    /// Container size — typically from the `GeometryReader` inside ``CardStack``.
    public let containerSize: CGSize

    /// Scroll axis of the stack.
    public let axis: CardStackAxis

    /// Size of each item along the main axis (height for vertical, width for horizontal).
    public let itemSize: CGFloat

    // MARK: - Init

    /// Creates a geometry calculator for a single render frame.
    /// - Parameters:
    ///   - config: Stack configuration.
    ///   - containerSize: Available container size.
    ///   - axis: Scroll axis (`.vertical` or `.horizontal`).
    ///   - itemSize: Item size along the main axis in points.
    public init(config: CardStackConfig, containerSize: CGSize, axis: CardStackAxis, itemSize: CGFloat) {
        self.config = config
        self.containerSize = containerSize
        self.axis = axis
        self.itemSize = itemSize
    }

    // MARK: - Private Helpers

    /// Length of the container along the main axis.
    /// Height for `.vertical`, width for `.horizontal`.
    private var mainAxisLength: CGFloat {
        axis == .vertical ? containerSize.height : containerSize.width
    }

    // MARK: - Spacing

    /// Dynamic spacing between cards in the top stack.
    ///
    /// Starts at `config.maxSpacing` and compresses as more cards arrive,
    /// always reserving `config.minPendingVisible` space for the pending pile.
    /// Never drops below `config.minSpacing` to prevent cards from fully overlapping.
    ///
    /// - Parameter arrived: Number of cards that have fully arrived (`engine.arrivedCount`).
    /// - Returns: Spacing in points, clamped to `[minSpacing, maxSpacing]`.
    public func effectiveSpacing(arrived: CGFloat) -> CGFloat {
        guard arrived > 1 else { return config.maxSpacing }

        // Usable space = container - paddings - pending pile reserve - one card
        let usable = mainAxisLength
            - config.topPadding
            - config.bottomPadding
            - config.minPendingVisible
            - itemSize

        // Distribute available space across gaps (N cards → N-1 gaps)
        let maxForRoom = usable / (arrived - 1)
        return max(config.minSpacing, min(config.maxSpacing, maxForRoom))
    }

    // MARK: - Stack Origin

    /// Origin position of the top stack along the main axis.
    ///
    /// Applies the configured `activeAnchor` to control how far the active card
    /// can travel, then ensures the full stack does not invade the space reserved
    /// for the pending pile.
    ///
    /// - Parameters:
    ///   - arrived: Number of cards that have fully arrived.
    ///   - spacing: Effective spacing from ``effectiveSpacing(arrived:)``.
    /// - Returns: Y position (vertical) or X position (horizontal) of the top stack's leading edge.
    public func stackOrigin(arrived: CGFloat, spacing: CGFloat) -> CGFloat {
        // Horizontal: stack grows from right to left.
        // Origin is the left edge of the rightmost (active) card.
        // leadingPadding/trailingPadding map to left/right respectively.
        if axis == .horizontal {
            let rawOrigin = mainAxisLength - itemSize - config.trailingPadding

            let anchoredOrigin: CGFloat = {
                switch config.activeAnchor {
                case .top, .free:
                    return rawOrigin
                case .center:
                    let minActivePos = mainAxisLength / 2 - itemSize / 2
                    let activeIfRaw  = rawOrigin - (arrived - 1) * spacing
                    return activeIfRaw < minActivePos
                        ? rawOrigin + (minActivePos - activeIfRaw)
                        : rawOrigin
                }
            }()

            let leftOfStack = anchoredOrigin - (arrived - 1) * spacing
            let overflow    = max(0, (config.leadingPadding + config.minPendingVisible) - leftOfStack)
            return anchoredOrigin + overflow
        }

        // Vertical: stack grows downward from topPadding.
        let rawOrigin = config.topPadding

        let anchoredOrigin: CGFloat = {
            switch config.activeAnchor {
            case .top:
                return rawOrigin
            case .center:
                let maxActivePos = mainAxisLength / 2 - itemSize / 2
                let activeIfRaw  = rawOrigin + (arrived - 1) * spacing
                return activeIfRaw > maxActivePos
                    ? rawOrigin - (activeIfRaw - maxActivePos)
                    : rawOrigin
            case .free:
                return rawOrigin
            }
        }()

        let stackHeight   = itemSize + (arrived - 1) * spacing
        let bottomOfStack = anchoredOrigin + stackHeight
        let overflow      = max(0, bottomOfStack - (mainAxisLength - config.bottomPadding - config.minPendingVisible))
        return anchoredOrigin - overflow
    }

    // MARK: - Card Positions

    /// Final destination position of a card in the top stack.
    ///
    /// - Parameters:
    ///   - index: Card index.
    ///   - spacing: Effective spacing from ``effectiveSpacing(arrived:)``.
    ///   - origin: Stack origin from ``stackOrigin(arrived:spacing:)``.
    /// - Returns: Leading-edge position of the card along the main axis.
    public func destPosition(index: Int, spacing: CGFloat, origin: CGFloat) -> CGFloat {
        // Vertical:   cards grow downward  — higher index = further down
        // Horizontal: cards grow leftward  — higher index = further right (origin)
        //             lower indices step left by one spacing each
        if axis == .horizontal {
            return origin - CGFloat(index) * spacing
        }
        return origin + CGFloat(index) * spacing
    }

    /// Resting position of a card in the pending (bottom/side) pile.
    ///
    /// Cards are ordered by queue position: the next card to move is closest
    /// to the top stack, with subsequent cards offset by `config.pendingPeek`.
    ///
    /// - Parameters:
    ///   - index: Card index.
    ///   - nextIndex: Index of the next card to move up (`engine.nextIndex`).
    ///   - arrived: Number of cards that have fully arrived.
    ///   - spacing: Effective spacing from ``effectiveSpacing(arrived:)``.
    /// - Returns: Leading-edge position of the card in the pending pile along the main axis.
    public func pendingPosition(index: Int, nextIndex: Int, arrived: CGFloat, spacing: CGFloat) -> CGFloat {
        let queuePos = max(0, index - nextIndex)

        if axis == .horizontal {
            // Pending pile sits to the left of the top stack.
            // Base is anchored to the left edge of the screen.
            let leftOfStackBase = (mainAxisLength - itemSize - config.trailingPadding) - arrived * spacing - itemSize
            let base = min(leftOfStackBase, config.leadingPadding)
            // Each card in the queue steps further left
            return base - CGFloat(queuePos) * config.pendingPeek
        }

        // Vertical: pending pile sits below the top stack.
        let topOfPendingBase = config.topPadding + arrived * spacing + itemSize
        let base = max(topOfPendingBase, mainAxisLength - itemSize - config.bottomPadding)
        return base + CGFloat(queuePos) * config.pendingPeek
    }

    /// Interpolated current position of a card between its pending and destination positions.
    ///
    /// Called every frame to smooth movement during a gesture.
    ///
    /// - Parameters:
    ///   - destPos: Destination position from ``destPosition(index:spacing:origin:)``.
    ///   - stackPos: Pending position from ``pendingPosition(index:nextIndex:arrived:spacing:)``.
    ///   - progress: Movement progress `[0, 1]` from ``CardStackEngine/progress(for:)``.
    /// - Returns: Interpolated position along the main axis.
    public func currentPosition(destPos: CGFloat, stackPos: CGFloat, progress: CGFloat) -> CGFloat {
        stackPos + (destPos - stackPos) * progress
    }

    // MARK: - Cross-Axis

    /// Center of the container along the cross axis.
    /// Cards are centered on this point using `.position()`.
    public var crossAxisCenter: CGFloat {
        axis == .vertical ? containerSize.width / 2 : containerSize.height / 2
    }

    /// Available card size along the cross axis, minus leading and trailing padding.
    public var itemCrossAxisSize: CGFloat {
        let crossAxis = axis == .vertical ? containerSize.width : containerSize.height
        return crossAxis - config.leadingPadding - config.trailingPadding
    }
}
