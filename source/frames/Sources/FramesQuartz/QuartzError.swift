//
//  QuartzError.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

package enum QuartzError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownKernel(name: String)
    case unappliedKernel(name: String)
    case unsupportedBlend(name: String, place: String)
    case kernelFailed(name: String)
    case faceNotInFile(file: String, face: String)
    case unmadeBitmap(width: Int, height: Int)
    case unrenderedImage

    // MARK: - Property
    package var description: String {
        switch self {
        case let .unknownKernel(name):
            "the quartz kernel library has no kernel \(name)"

        case let .unappliedKernel(name):
            "the quartz kernel \(name) does not take the arguments it was given"

        case let .unsupportedBlend(name, place):
            "the quartz renderer has no blend mode \(name) at \(place)"

        case let .kernelFailed(name):
            "the quartz colour kernel \(name) gave no image"

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
