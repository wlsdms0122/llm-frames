//
//  FrameTime.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreMedia

// A frame's two timestamps. `sample` is on the track's media timeline, which an undecoded sample carries, and
// `presented` is on the file's presentation timeline, after the edit list, which a decoded sample and a reader's time
// range carry.
struct FrameTime: Sendable {
    // MARK: - Property
    let sample: CMTime
    let presented: CMTime

    // MARK: - Initializer
    init(
        sample: CMTime,
        presented: CMTime
    ) {
        self.sample = sample
        self.presented = presented
    }

    // MARK: - Public
    // MARK: - Private
}
