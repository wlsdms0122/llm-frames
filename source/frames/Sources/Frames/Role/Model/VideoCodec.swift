//
//  VideoCodec.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The codecs a compressed video is written with, by the names `--codec` takes.
package enum VideoCodec: String, CaseIterable, Sendable {
    case h264
    case hevc

    // MARK: - Property
    package var name: String {
        switch self {
        case .h264:
            "H.264"

        case .hevc:
            "HEVC"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
