//
//  LocationHit.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// An item under the point: the clip that drew it, nil where `evaluate` names none, what it draws, and for a picture of
// media where the point falls in that media.
package struct LocationHit: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let item: ItemKind
    package let media: LocatedMedia?

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        item: ItemKind,
        media: LocatedMedia?
    ) {
        self.origin = origin
        self.item = item
        self.media = media
    }

    // The flattened item under `point`, in output pixels.
    init(
        _ item: FlattenedItem,
        point: Point
    ) {
        self.init(origin: item.origin, item: item.item, media: item.media.map { LocatedMedia($0, point: point) })
    }

    // MARK: - Public
    // MARK: - Private
}
