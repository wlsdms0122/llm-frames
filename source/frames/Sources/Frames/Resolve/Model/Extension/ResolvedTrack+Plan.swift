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

    // A connected or sequence clip's track, in the media of the storyline clip it is parented to, which tracking has
    // found to be a video or image sequence.
    init?(
        track: StorylineTrack,
        hashes: any FileHashProvider
    ) throws {
        guard case let .file(file) = track.storyline.source.media?.source else { return nil }

        try self.init(track: track.track, file: file, hashes: hashes)
    }

    // MARK: - Public
    // MARK: - Private
}
