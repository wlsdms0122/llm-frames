//
//  ClipContent.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a connected or sequence clip is, by the one kind key it holds.
enum ClipContent: Equatable, Sendable {
    case media(ClipMedia)
    case title(style: String)
    case shape(String)
    case adjust
}
