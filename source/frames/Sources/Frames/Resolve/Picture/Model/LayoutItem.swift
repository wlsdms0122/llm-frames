//
//  LayoutItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One picture of a layout, with the heading above its cell.
struct LayoutItem: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let heading: String?
    let source: MediaSource

    // MARK: - Initializer
    init(
        place: Place,
        heading: String?,
        source: MediaSource
    ) {
        self.place = place
        self.heading = heading
        self.source = source
    }

    // MARK: - Public
    // MARK: - Private
}
