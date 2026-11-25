//
//  ResolvedStorylineContent.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a storyline entry shows: a solid, or media with how its picture is placed and drawn.
enum ResolvedStorylineContent: Equatable, Sendable {
    case solid(ResolvedSolid)
    case media(ResolvedStorylineMedia)
}
