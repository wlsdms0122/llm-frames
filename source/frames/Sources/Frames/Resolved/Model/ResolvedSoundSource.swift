//
//  ResolvedSoundSource.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a sound plays: its pinned media, or the sounds of a nested sequence, on their own clock, with that sequence's own
// audio filter, its bus's chain, on the same clock, `off` for none.
enum ResolvedSoundSource: Equatable, Sendable {
    case pinned(PinnedMedia)
    case nested([ResolvedSound], audioFilter: TimedValue)
}
