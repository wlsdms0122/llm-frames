//
//  ItemTrackMatte.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// `source` is a nested list the size of the list that holds the item, in that list's output pixels, and empty outside
// the matte clip's visible window. At each point the item's alpha is multiplied by the source's alpha or luma there,
// as `mode` says, or by 1 minus that when inverted.
package struct ItemTrackMatte: Equatable, Sendable {
    // MARK: - Property
    package let source: DisplayList
    package let mode: TrackMatteMode
    package let isInverted: Bool

    // MARK: - Initializer
    package init(
        source: DisplayList,
        mode: TrackMatteMode,
        isInverted: Bool
    ) {
        self.source = source
        self.mode = mode
        self.isInverted = isInverted
    }

    // MARK: - Public
    // MARK: - Private
}
