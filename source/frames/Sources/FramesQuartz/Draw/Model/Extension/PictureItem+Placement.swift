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
        let region = rectangle.map(CGRect.init) ?? CGRect(origin: .zero, size: size)
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

    // MARK: - Private
}
