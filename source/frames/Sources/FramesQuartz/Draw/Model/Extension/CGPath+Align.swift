//
//  CGPath+Align.swift
//  FramesQuartz
//
//  Created by JSilver on 11/24/26.
//

import CoreGraphics
import Frames

// A centred stroke's shape cut to one side of the outline it follows, as a stroke on that side is drawn.
extension CGPath {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The shape cut to the side of `outline` that `align` names: inside it, the region its fill covers by the nonzero
    // rule, outside it, or whole for a centred stroke. Nil where nothing of it is left.
    func cut(
        to align: StrokeAlign,
        of outline: PathOutline
    ) -> CGPath? {
        let cut = switch align {
        case .inside:
            intersection(outline.fillPath, using: .winding)

        case .center:
            self

        case .outside:
            subtracting(outline.fillPath, using: .winding)
        }

        return cut.isEmpty ? nil : cut
    }

    // MARK: - Private
}
