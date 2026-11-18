//
//  TrackedFrame+Rectangle.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames

// A frame on which a tracker that follows only position and size found the target's rectangle.
extension TrackedFrame {
    // MARK: - Property
    // MARK: - Initializer
    init(
        time: Double,
        rectangle: Rectangle
    ) {
        self.init(time: time, quad: Quad(rectangle))
    }

    // MARK: - Public
    // MARK: - Private
}
