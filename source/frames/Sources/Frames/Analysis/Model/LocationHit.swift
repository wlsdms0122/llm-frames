//
//  LocationHit.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// An item under the point: the clip that drew it, nil where `evaluate` names none, and for a picture of media where
// the point falls in that media.
package struct LocationHit: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let media: LocatedMedia?

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        media: LocatedMedia?
    ) {
        self.origin = origin
        self.media = media
    }

    // The flattened item under `point`, in output pixels.
    init(
        _ item: FlattenedItem,
        point: Point
    ) {
        self.init(origin: item.origin, media: item.media.map { LocatedMedia($0, point: point) })
    }

    // MARK: - Public
    // MARK: - Private
}
