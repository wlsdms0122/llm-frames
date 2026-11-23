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
    package let filter: [FilterEntry]

    // MARK: - Initializer
    package init(filter: [FilterEntry]) {
        self.filter = filter
    }

    // MARK: - Public
    // What the item draws in its own coordinates, which its reveal wipes across: the frame of its list carried back by
    // the inverse of `transform`, since the item covers that frame wherever its transform carries its reveal, cut to
    // what `masks` let through. A mask lets through its geometry's box grown by its feather's reach, and the whole frame
    // where it is inverted; `add` joins that box to the masks before it, `intersect` meets it, and `subtract` keeps them,
    // since it only takes away. Where no mask lets anything through the item draws nothing, and the frame stands. Nil
    // where the transform flattens the plane, which leaves nothing drawn.
    package func drawnBounds(
        carriedBy transform: AffineTransform,
        masks: [ItemMask],
        over frame: Rectangle
    ) -> Rectangle? {
        guard let inverse = transform.inverse else { return nil }

        let whole = Rectangle(bounding: inverse.apply(toCornersOf: frame))
        guard let first = masks.first else { return whole }

        let start: Rectangle? = first.mode == .add ? nil : whole
        let shown = masks.reduce(start) { shown, mask in
            let box = mask.isInverted ? whole : bounds(of: mask, under: transform, inverse: inverse)
            switch mask.mode {
            case .add:
                return shown.map { $0.union(box) } ?? box

            case .subtract:
                return shown

            case .intersect:
                return shown.flatMap { meeting($0, box) }
            }
        }

        return shown.flatMap { meeting($0, whole) } ?? whole
    }

    // MARK: - Private
    // The box of the mask's geometry in the item's coordinates, grown by its feather's reach. A mask carried by the
    // item's own transform keeps its box as written.
    private func bounds(
        of mask: ItemMask,
        under transform: AffineTransform,
        inverse: AffineTransform
    ) -> Rectangle {
        let relative = mask.transform == transform ? AffineTransform.identity : mask.transform.concatenating(inverse)
        let box = switch mask.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            relative == .identity ? rectangle : Rectangle(bounding: relative.apply(toCornersOf: rectangle))

        case .path:
            mask.geometry.bounds(carriedBy: relative)
        }
        guard mask.feather > 0 else { return box }

        // The feather is in output pixels, so the disc it reaches is carried back by the inverse.
        let reach = inverse.reach(ofDisc: ItemMask.featherReach * mask.feather)
        return Rectangle(
            x: box.x - reach.width,
            y: box.y - reach.height,
            width: box.width + 2 * reach.width,
            height: box.height + 2 * reach.height
        )
    }

    // The part two boxes share, either one itself where it lies inside the other, so a box is kept as written.
    private func meeting(
        _ box: Rectangle,
        _ other: Rectangle
    ) -> Rectangle? {
        if other.contains(box) { return box }
        if box.contains(other) { return other }

        return box.intersection(other)
    }
}
