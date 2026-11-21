//
//  AnimationPass.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One play of an animation's span: its entrance, one period of its loop, or its exit, from `start` for `length`
// seconds. Its progress is 0 at its start and 1 at its end.
struct AnimationPass: Equatable, Sendable {
    // MARK: - Property
    let span: Span
    let start: Double
    let length: Double

    var end: Double {
        start + length
    }

    // MARK: - Initializer
    init(
        span: Span,
        start: Double,
        length: Double
    ) {
        self.span = span
        self.start = start
        self.length = length
    }

    // MARK: - Public
    func progress(at time: Double) -> Double {
        (time - start) / length
    }

    // MARK: - Private
}
