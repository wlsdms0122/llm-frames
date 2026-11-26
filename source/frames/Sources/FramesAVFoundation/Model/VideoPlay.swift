//
//  VideoPlay.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import Frames

// One play of the video at `path`, which has a reader of its own (FRAMES-21 Rules).
struct VideoPlay: Hashable, Sendable {
    // MARK: - Property
    let path: String
    let play: MediaPlay

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
