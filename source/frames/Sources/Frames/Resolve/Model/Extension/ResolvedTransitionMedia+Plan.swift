//
//  ResolvedTransitionMedia+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A cover or matte file as probed, pinned with its frame times and its length, read in the colour space its preset
// writes.
extension ResolvedTransitionMedia {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: TransitionMedia,
        colorSpace: ColorSpace?,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            media: try PinnedMedia(file: plan.file, hashes: hashes),
            colorSpace: colorSpace,
            duration: plan.duration
        )
    }

    // MARK: - Public
    // MARK: - Private
}
