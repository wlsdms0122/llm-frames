//
//  FlattenedItem.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One item of a display list with every list it is nested in flattened away, in output pixels: the clip that drew it,
// what it draws, its opacity times the opacity of every picture holding it, what it covers of the output, and for a
// picture of media where that media is drawn.
struct FlattenedItem: Equatable, Sendable {
    // MARK: - Property
    let origin: ItemOrigin?
    let item: ItemKind
    let opacity: Double
    let coverage: ItemCoverage
    let media: MediaPlacement?

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        item: ItemKind,
        opacity: Double,
        coverage: ItemCoverage,
        media: MediaPlacement? = nil
    ) {
        self.origin = origin
        self.item = item
        self.opacity = opacity
        self.coverage = coverage
        self.media = media
    }

    // MARK: - Public
    // MARK: - Private
}
