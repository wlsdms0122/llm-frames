//
//  ProbedMedium.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// What the probe finds a file to be: a PDF, by its page count, or media of another kind, by its facts. A page of a PDF
// is probed on its own (`MediaFactProvider.probedPage`).
package enum ProbedMedium: Equatable, Sendable {
    case pdf(pageCount: Int)
    case media(ProbedMedia)

    // MARK: - Property
    // A PDF is of the kind of each of its pages.
    var kind: MediaKind {
        switch self {
        case .pdf:
            .page

        case let .media(probed):
            probed.kind
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
