//
//  ClipNull.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a null clip writes of its own: the size of its box when it is given by `width` and `height`, each nil where not
// written, keyframes on the clip's clock. Its `area` and the keys that place and move it are the clip's.
struct ClipNull: Equatable, Sendable {
    // MARK: - Property
    let width: PropertyValue<Double>?
    let height: PropertyValue<Double>?

    // A null given by `width` and `height` is placed by its box, and one given by `area` by its area. A null missing
    // one of the two is neither and stops when its geometry is planned.
    var isPlacedByBox: Bool { width != nil && height != nil }

    // MARK: - Initializer
    init(
        width: PropertyValue<Double>? = nil,
        height: PropertyValue<Double>? = nil
    ) {
        self.width = width
        self.height = height
    }

    // MARK: - Public
    // MARK: - Private
}
