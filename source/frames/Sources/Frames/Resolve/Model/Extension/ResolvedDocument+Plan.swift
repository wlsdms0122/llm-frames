//
//  ResolvedDocument+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a document, with every file it names pinned through `hashes`.
extension ResolvedDocument {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: DocumentPlan,
        hashes: any FileHashProvider
    ) throws {
        switch plan {
        case let .sequence(sequence):
            self = .sequence(try ResolvedSequence(plan: sequence, hashes: hashes))

        case let .picture(picture):
            self = .picture(try ResolvedPicture(plan: picture, hashes: hashes))
        }
    }

    // MARK: - Public
    // MARK: - Private
}
