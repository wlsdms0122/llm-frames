//
//  ResolvedTransitionMedia+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A cover or matte file as probed, pinned with its frame times and its length.
extension ResolvedTransitionMedia {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: TransitionMedia,
        hashes: any FileHashProvider
    ) throws {
        self.init(media: try PinnedMedia(file: plan.file, hashes: hashes), duration: plan.duration)
    }

    // MARK: - Public
    // MARK: - Private
}
