//
//  SoundPlanSource.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// What a source of sound plays: a media file, or the sounds of a compound clip or a sequence document on its own clock
// with that sequence's own audio filter, its bus's chain, on the same clock, `off` for none.
enum SoundPlanSource: Equatable, Sendable {
    case file(MediaFile)
    case nested([SoundPlan], audioFilter: TimedValue)
}
