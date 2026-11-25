//
//  ResolvedCoverSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a cover shows: a solid colour as a value, or media.
enum ResolvedCoverSource: Equatable, Sendable {
    case solid(Color)
    case media(ResolvedTransitionMedia)
}
