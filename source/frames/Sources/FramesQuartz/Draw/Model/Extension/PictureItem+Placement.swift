//
//  PictureItem+Placement.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Frames

extension PictureItem {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The map from the coordinates of a source of `size` into the item's that carries the picture's region onto its
    // destination, nil when the region or the destination is empty.
    func placement(ofSourceSized size: CGSize) -> CGAffineTransform? {
        let region = sourceRegion(sized: size)
        guard region.width > 0, region.height > 0, destination.width > 0, destination.height > 0 else { return nil }

        let scaleX = destination.width / region.width
        let scaleY = destination.height / region.height

        return CGAffineTransform(
            a: scaleX,
            b: 0,
            c: 0,
            d: scaleY,
            tx: destination.x - region.minX * scaleX,
            ty: destination.y - region.minY * scaleY
        )
    }

    // The rectangle of a source of `size` that the picture shows, in the source's coordinates: the part of its region
    // inside the source, which the placement carries onto the part of the destination the source covers. Nil when they
    // do not meet.
    func shownSource(ofSourceSized size: CGSize) -> CGRect? {
        let shown = sourceRegion(sized: size).intersection(CGRect(origin: .zero, size: size))
        guard !shown.isNull, !shown.isEmpty else { return nil }

        return shown
    }

    // The source's bounds in its coordinates with each side that lies on or past the region's side moved out without
    // bound, so a picture cut to its destination afterwards is covered at the destination's edge by that cut alone, and
    // by the source's own edge where it lies inside the destination.
    func extendedSource(ofSourceSized size: CGSize) -> CGRect {
        let region = sourceRegion(sized: size)
        let far = PictureResampler.unbounded
        let left = region.minX >= 0 ? -far : 0
        let top = region.minY >= 0 ? -far : 0
        let right = region.maxX <= size.width ? far : size.width
        let bottom = region.maxY <= size.height ? far : size.height

        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    // MARK: - Private
    private func sourceRegion(sized size: CGSize) -> CGRect {
        rectangle.map(CGRect.init) ?? CGRect(origin: .zero, size: size)
    }
}
