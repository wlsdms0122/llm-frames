//
//  Arrow.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An arrow pointing at an area from one side: its tip at the middle of that side, its tail the theme's arrow length
// beyond it, and the box it fills from tail to head, as wide as the head or the line, whichever is wider. Theme lengths
// are multiplied by `scale`.
struct Arrow: Equatable, Sendable {
    // MARK: - Property
    let tip: Point
    let tail: Point
    let box: Rectangle

    // MARK: - Initializer
    init(
        pointingAt area: Rectangle,
        from side: Side,
        theme: MergedTheme,
        scale: Double
    ) {
        let length = theme.arrowLength * scale
        let breadth = max(theme.arrowHead, theme.arrowWidth) * scale
        let tip = area.point(named: side.rawValue)
        self.tip = tip
        switch side {
        case .left:
            self.tail = Point(x: tip.x - length, y: tip.y)
            self.box = Rectangle(x: tip.x - length, y: tip.y - breadth / 2, width: length, height: breadth)

        case .right:
            self.tail = Point(x: tip.x + length, y: tip.y)
            self.box = Rectangle(x: tip.x, y: tip.y - breadth / 2, width: length, height: breadth)

        case .top:
            self.tail = Point(x: tip.x, y: tip.y - length)
            self.box = Rectangle(x: tip.x - breadth / 2, y: tip.y - length, width: breadth, height: length)

        case .bottom:
            self.tail = Point(x: tip.x, y: tip.y + length)
            self.box = Rectangle(x: tip.x - breadth / 2, y: tip.y, width: breadth, height: length)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
