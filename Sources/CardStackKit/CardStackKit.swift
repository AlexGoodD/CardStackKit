// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  A SwiftUI component for rendering data collections
//  as a stack of layered cards, with gesture support,
//  vertical and horizontal axes, and configurable snap behavior.
//
//  ## Quick start
//  ```swift
//  CardStack(items: myCards, axis: .vertical, itemSize: 220) { card, ctx in
//      MyCardView(card: card)
//          .frame(width: ctx.crossAxisSize, height: 220)
//          .position(x: ctx.crossAxisPosition, y: ctx.mainAxisPosition + 110)
//          .zIndex(ctx.zIndex)
//  }
//  .pendingVisible(5)
//  .spacing(min: 24, max: 60)
//  .activeAnchor(.center)
//  ```
//
//  ## Public types
//  - ``CardStack``             Main view
//  - ``CardStackItemContext``  Position context delivered to each card
//  - ``CardStackConfig``       Behavior configuration
//  - ``CardStackAxis``         Scroll axis (.vertical / .horizontal)
//  - ``CardStackEngine``       State engine (advanced)
//  - ``CardStackGeometry``     Position calculator (advanced)
