//
//  StorylineContent.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a storyline clip shows as resolve found it: a solid's colour, keyframes in sequence time, its media file, or the
// plan of the nested sequence a compound clip or a template instance shows.
enum StorylineContent: Equatable, Sendable {
    case solid([Keyframe<Color>])
    case file(MediaFile)
    case nested(SequencePlan)
}
