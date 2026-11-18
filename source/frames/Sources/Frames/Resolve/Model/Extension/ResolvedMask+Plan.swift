//
//  ResolvedMask+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A mask as resolve gives it: a rect or an ellipse on its area, or on its box centred on its position, and
// a path as a closed polyline, in the clip's own coordinate space, and its feather, a theme length, in output pixels.
extension ResolvedMask {
    // MARK: - Property
    // MARK: - Initializer
    init(
        mask: ClipMask,
        geometry: FoundMaskGeometry,
        lengthScale: Double
    ) {
        let rectangle: Rectangle
        switch geometry {
        case let .area(area):
            rectangle = area

        case let .box(width, height, position):
            rectangle = Rectangle(center: position, width: width, height: height)

        case let .points(points):
            self.init(mask: mask, geometry: .polyline(points, isClosed: true), lengthScale: lengthScale)
            return
        }

        let path: PathGeometry = mask.shape == .ellipse ? .ellipse(rectangle) : .rect(rectangle, radius: mask.radius)
        self.init(mask: mask, geometry: path, lengthScale: lengthScale)
    }

    // MARK: - Public
    // MARK: - Private
    private init(
        mask: ClipMask,
        geometry: PathGeometry,
        lengthScale: Double
    ) {
        self.init(
            geometry: geometry,
            feather: mask.feather * lengthScale,
            isInverted: mask.isInverted,
            mode: mask.mode
        )
    }
}
