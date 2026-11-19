//
//  ResolvedTrack+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A track with the media it followed pinned.
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    init(
        track: Track,
        file: MediaFile,
        hashes: any FileHashProvider
    ) throws {
        self.init(media: try PinnedMedia(file: file, hashes: hashes), track: track)
    }

    init(
        track: TrackedMedia,
        hashes: any FileHashProvider
    ) throws {
        try self.init(track: track.track, file: track.file, hashes: hashes)
    }

    // MARK: - Public
    // MARK: - Private
}
