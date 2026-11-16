//
//  AdjustItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter applied to everything drawn below it, inside `rectangle`, or over the whole frame when it is nil.
struct AdjustItem: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle?
    let filter: [ResolvedFilterOperation]

    // MARK: - Initializer
    init(
        rectangle: Rectangle?,
        filter: [ResolvedFilterOperation]
    ) {
        self.rectangle = rectangle
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}
