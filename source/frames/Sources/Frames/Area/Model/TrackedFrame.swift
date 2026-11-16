//
//  TrackedFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The target's rectangle in media pixels on the frame at `time`, in media seconds.
struct TrackedFrame: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let rectangle: Rectangle

    // MARK: - Initializer
    init(
        time: Double,
        rectangle: Rectangle
    ) {
        self.time = time
        self.rectangle = rectangle
    }

    // MARK: - Public
    // MARK: - Private
}
