//
//  ResolvedSequence.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A resolved sequence: its format, its storyline, its other clips in document order (an audio clip is drawn by nothing,
// so it is not among them), every source of sound, and `audioFilter`, its own audio filter, its bus's chain, as a timed
// list of entries `{ops, mix}` in its sequence time, `off` for none.
package struct ResolvedSequence: Equatable, Sendable {
    // MARK: - Property
    let format: ResolvedFormat
    let storyline: [ResolvedStorylineClip]
    let clips: [ResolvedClip]
    let audio: [ResolvedSound]
    let audioFilter: TimedValue

    // MARK: - Initializer
    init(
        format: ResolvedFormat,
        storyline: [ResolvedStorylineClip],
        clips: [ResolvedClip],
        audio: [ResolvedSound],
        audioFilter: TimedValue = .off
    ) {
        self.format = format
        self.storyline = storyline
        self.clips = clips
        self.audio = audio
        self.audioFilter = audioFilter
    }

    // MARK: - Public
    // MARK: - Private
}
