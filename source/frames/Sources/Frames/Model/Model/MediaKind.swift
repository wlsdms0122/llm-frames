//
//  MediaKind.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The media types of template parameters: a video or image sequence, a compound clip, a picture, a sound.
package enum MediaKind: String, CaseIterable, Sendable {
    case video
    case sequence
    case image
    case audio
}
