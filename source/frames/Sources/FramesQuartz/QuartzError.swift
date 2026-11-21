//
//  QuartzError.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

package enum QuartzError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownKernel(name: String)
    case unsupportedBlend(name: String, place: String)
    case unreadableTable(place: String, error: FilterError)
    case unsupportedCornerPin(place: String)
    case nonConvexCornerPin(place: String)
    case kernelFailed(name: String)
    case faceNotInFile(file: String, face: String)
    case unmadeBitmap(width: Int, height: Int)
    case unrenderedImage

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unknownKernel(name):
            "the quartz kernel library has no kernel \(name)"

        case let .unsupportedBlend(name, place):
            "the quartz renderer has no blend mode \(name) at \(place)"

        case let .unreadableTable(place, error):
            "the quartz renderer cannot read the LUT at \(place): \(error)"

        case let .unsupportedCornerPin(place):
            "the quartz renderer draws a corner pin only on a picture of a nested display list with no filter, matte, "
                + "radius, border, shadow or reveal, as a clip's group is, found one at \(place)"

        case let .nonConvexCornerPin(place):
            "the quartz renderer draws a corner pin that is a strictly convex quadrilateral, or in a sample list four "
                + "points at [0, 0], found another at \(place)"

        case let .kernelFailed(name):
            "the quartz kernel \(name) gave no image"

        case let .faceNotInFile(file, face):
            "the quartz renderer found no face \(face) in the font file \(file)"

        case let .unmadeBitmap(width, height):
            "the quartz renderer could not make a \(width) x \(height) bitmap"

        case .unrenderedImage:
            "the quartz renderer could not render a Core Image image to a bitmap"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
