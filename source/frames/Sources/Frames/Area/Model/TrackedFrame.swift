//
//  TrackedFrame.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The target's rectangle in media pixels on the frame at `time`, in media seconds.
package struct TrackedFrame: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let rectangle: Rectangle

    // MARK: - Initializer
    package init(
        time: Double,
        rectangle: Rectangle
    ) {
        self.time = time
        self.rectangle = rectangle
    }

    // MARK: - Public
    // MARK: - Private
}
