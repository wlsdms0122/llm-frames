//
//  QuartzError.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

package enum QuartzError: Error, Equatable, CustomStringConvertible, Sendable {
    // Placeholder until the renderer draws.
    case notImplemented
    case unknownKernel(name: String)
    case unappliedKernel(name: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case .notImplemented:
            "the quartz renderer does not draw yet"

        case let .unknownKernel(name):
            "the quartz kernel library has no colour kernel \(name)"

        case let .unappliedKernel(name):
            "the quartz kernel \(name) does not take the arguments it was given"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
