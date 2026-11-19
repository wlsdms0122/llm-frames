//
//  TextUnderline.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A band under a run's glyphs, `width` thick with its top edge `offset` below the baseline, in output pixels. A leaf
// no layer gives is nil, and the run's face and colour give it when the run is set.
struct TextUnderline: Equatable, Sendable {
    // MARK: - Property
    let width: Double?
    let offset: Double?
    let color: Color?

    // MARK: - Initializer
    init(
        width: Double?,
        offset: Double?,
        color: Color?
    ) {
        self.width = width
        self.offset = offset
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}
