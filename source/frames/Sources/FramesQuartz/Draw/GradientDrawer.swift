//
//  GradientDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Frames

// Paints a gradient over the context's clip in the item's own coordinates, so the transform carries it with the
// geometry and a radial gradient is drawn as an ellipse where the axes are scaled apart. Past its ends it holds its
// end colours. A degenerate gradient paints its last stop's colour.
struct GradientDrawer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func draw(
        _ gradient: Gradient,
        in context: CGContext
    ) {
        guard !gradient.isDegenerate, let function = GradientRamp(gradient).function() else {
            guard let last = gradient.stops.last else { return }

            context.setFillColor(last.color.cgColor)
            context.fill(context.boundingBoxOfClipPath)
            return
        }

        let shading = switch gradient.shape {
        case let .linear(from, to):
            CGShading(
                axialSpace: WorkingSpace.colorSpace,
                start: CGPoint(x: from.x, y: from.y),
                end: CGPoint(x: to.x, y: to.y),
                function: function,
                extendStart: true,
                extendEnd: true
            )

        case let .radial(center, radius):
            CGShading(
                radialSpace: WorkingSpace.colorSpace,
                start: CGPoint(x: center.x, y: center.y),
                startRadius: 0,
                end: CGPoint(x: center.x, y: center.y),
                endRadius: CGFloat(radius),
                function: function,
                extendStart: true,
                extendEnd: true
            )
        }
        guard let shading else { return }

        context.drawShading(shading)
    }

    // MARK: - Private
}
