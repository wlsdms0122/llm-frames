//
//  ResolvedCoverSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a cover shows: a colour as a value, or media.
enum ResolvedCoverSource: Equatable, Sendable {
    case color(Color)
    case media(ResolvedTransitionMedia)
}
