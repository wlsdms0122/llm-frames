//
//  LaneSide.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Which side of what they are composited with clips stack on: `below` for negative lanes, `above` for positive ones.
enum LaneSide: Sendable {
    case below
    case above
}
