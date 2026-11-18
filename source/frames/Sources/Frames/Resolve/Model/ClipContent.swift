//
//  ClipContent.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipContent: Equatable, Sendable {
    case media(ClipMedia)
    case title(runs: [TitleRun], style: String)
    case shape(ClipShape)
    case adjust
}
