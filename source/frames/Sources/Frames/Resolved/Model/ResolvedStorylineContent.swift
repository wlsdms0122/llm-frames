//
//  ResolvedStorylineContent.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a storyline entry shows: a solid's colour, keyframes in sequence time, or media.
enum ResolvedStorylineContent: Equatable, Sendable {
    case solid([Keyframe<Color>])
    case media(ResolvedStorylineMedia)
}
