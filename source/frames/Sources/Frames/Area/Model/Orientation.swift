//
//  Orientation.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The way a strictly convex quad's corners run, top left, top right, bottom right, bottom left, in y-down pixels: the
// sign its four turns share (FRAMES-27).
package enum Orientation: Equatable, Sendable {
    // All four turns above 0, as a box's corners run.
    case clockwise
    // All four turns below 0: the clockwise quad mirrored, as a negative scale mirrors a clip.
    case counterclockwise
}
