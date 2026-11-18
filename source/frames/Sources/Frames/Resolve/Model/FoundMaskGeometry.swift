//
//  FoundMaskGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A mask's geometry as found, every text form searched: an area, a box of `width` by `height` centred on `position`,
// or a path's points.
enum FoundMaskGeometry: Equatable, Sendable {
    case area(Rectangle)
    case box(width: Double, height: Double, position: Point)
    case points([Point])
}
