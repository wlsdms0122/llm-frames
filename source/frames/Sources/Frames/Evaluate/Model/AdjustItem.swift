//
//  AdjustItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter applied to everything drawn below it, over the whole frame of its list, cut only by its item's mask, reveal
// and opacity.
package struct AdjustItem: Equatable, Sendable {
    // MARK: - Property
    package let filter: [ResolvedFilterOperation]

    // MARK: - Initializer
    package init(filter: [ResolvedFilterOperation]) {
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}
