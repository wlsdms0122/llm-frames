//
//  ResolvedSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A resolved sequence: its format, its storyline, its other clips in document order (an audio clip is drawn by nothing,
// so it is not among them), and every source of sound.
package struct ResolvedSequence: Equatable, Sendable {
    // MARK: - Property
    let format: ResolvedFormat
    let storyline: [ResolvedStorylineClip]
    let clips: [ResolvedClip]
    let audio: [ResolvedSound]

    // MARK: - Initializer
    init(
        format: ResolvedFormat,
        storyline: [ResolvedStorylineClip],
        clips: [ResolvedClip],
        audio: [ResolvedSound]
    ) {
        self.format = format
        self.storyline = storyline
        self.clips = clips
        self.audio = audio
    }

    // MARK: - Public
    // MARK: - Private
}
