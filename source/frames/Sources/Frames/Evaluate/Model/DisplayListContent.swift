//
//  DisplayListContent.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// What a display list holds: its items, bottom first, or, in the outermost list of a frame with motion blur, its sample
// lists in order, each a whole list of items of the frame at one instant of its exposure, whose mean is the frame
// (FRAMES-29). A nested list holds items.
package enum DisplayListContent: Equatable, Sendable {
    case items([DisplayItem])
    case samples([[DisplayItem]])
}
