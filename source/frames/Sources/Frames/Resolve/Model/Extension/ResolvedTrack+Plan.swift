//
//  ResolvedTrack+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    init(track: Track) {
        self.init(target: track.target, mediaTime: track.mediaTime, frames: track.frames)
    }

    // MARK: - Public
    // MARK: - Private
}
