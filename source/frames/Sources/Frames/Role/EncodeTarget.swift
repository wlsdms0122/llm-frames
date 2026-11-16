//
//  EncodeTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A video file an encoder writes. A master is ProRes 422 HQ, or ProRes 4444 with `alpha`, with 24-bit PCM sound at
// 48 kHz in stereo. A delivery is H.264 at the encoder's highest quality with AAC at 256 kbps, its transparent parts
// over black.
package enum EncodeTarget: Equatable, Sendable {
    case master(path: String, alpha: Bool)
    case delivery(path: String)
}
