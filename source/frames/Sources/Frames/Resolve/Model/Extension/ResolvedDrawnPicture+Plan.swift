//
//  ResolvedDrawnPicture+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The picture a drawing step shows, its media pinned and a nested document resolved in place.
extension ResolvedDrawnPicture {
    // MARK: - Property
    // MARK: - Initializer
    init(
        picture: DrawnPicture,
        hashes: any FileHashProvider
    ) throws {
        switch picture {
        case let .media(file, _, time):
            self = .media(try PinnedMedia(file: file, hashes: hashes), time: time)

        case let .picture(plan):
            self = .picture(try ResolvedPicture(plan: plan, hashes: hashes))

        case let .sequence(plan, time):
            self = .sequence(try ResolvedSequence(plan: plan, hashes: hashes), time: time)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
