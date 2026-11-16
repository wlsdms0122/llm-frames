//
//  ArrowItem+Motion.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An arrow moved by its animation: `nudge` slides it towards what it points at by multiples of its whole length, then
// `reveal` grows it from its tail, so a nudge measures the arrow before the reveal shortens it.
extension ArrowItem {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func moved(by motion: Motion) -> ArrowItem {
        let nudge = motion.value(of: .nudge)
        let offset = Point(x: (head.x - tail.x) * nudge, y: (head.y - tail.y) * nudge)
        let tail = Point(x: tail.x + offset.x, y: tail.y + offset.y)
        let head = Point(x: head.x + offset.x, y: head.y + offset.y)
        let reveal = Reveal(amount: motion.value(of: .reveal))

        return ArrowItem(
            tail: tail,
            head: reveal.head(growingFrom: tail, to: head),
            width: width,
            headSize: headSize,
            color: color
        )
    }

    // MARK: - Private
}
