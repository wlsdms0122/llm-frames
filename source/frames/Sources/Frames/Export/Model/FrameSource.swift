//
//  FrameSource.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `sheet` and `extract` take frames from: a video file by its absolute path, whose times are media times and
// whose frames are the ones shown at them, or a resolved document, whose times are sequence times.
package enum FrameSource: Equatable, Sendable {
    case video(path: String)
    case document(ResolvedSequence)
}
