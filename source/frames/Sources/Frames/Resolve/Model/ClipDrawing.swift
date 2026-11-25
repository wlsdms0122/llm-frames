//
//  ClipDrawing.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a connected or sequence clip draws: a picture, composited as its `opacity` and `blend` say, or nothing, for a
// null, which is placed as its geometry plan says, and for an audio clip, whose media is only heard.
enum ClipDrawing: Equatable, Sendable {
    case picture(ClipComposite)
    case null(NullGeometryPlan)
    case sound
}
