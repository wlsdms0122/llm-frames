//
//  ClipParent.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The clip a parented clip names by its `id`: a storyline clip by its index on the storyline, or a connected or
// sequence clip by its index among the clips of the document, in document order.
enum ClipParent: Equatable, Sendable {
    case storyline(index: Int, id: String)
    case clip(index: Int, id: String)

    // MARK: - Property
    var id: String {
        switch self {
        case let .storyline(_, id), let .clip(_, id):
            id
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
