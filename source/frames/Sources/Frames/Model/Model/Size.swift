//
//  Size.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

package struct Size: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let height: Double

    // MARK: - Initializer
    package init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    // MARK: - Public
    // MARK: - Private
}
