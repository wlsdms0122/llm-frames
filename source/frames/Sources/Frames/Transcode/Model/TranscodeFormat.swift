//
//  TranscodeFormat.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What a transcode wrote: an image format, AAC sound alone, or a video of `codec` with AAC sound or without sound.
package enum TranscodeFormat: Equatable, Sendable {
    case png
    case jpeg
    case heic
    case aac
    case video(codec: VideoCodec, hasSound: Bool)

    // MARK: - Property
    package var name: String {
        switch self {
        case .png:
            "PNG"

        case .jpeg:
            "JPEG"

        case .heic:
            "HEIC"

        case .aac:
            "AAC"

        case let .video(codec, hasSound):
            hasSound ? "\(codec.name) with AAC" : codec.name
        }
    }

    // MARK: - Initializer
    init(_ target: ImageTarget) {
        switch target {
        case .png:
            self = .png

        case .jpeg:
            self = .jpeg

        case .heic:
            self = .heic
        }
    }

    // MARK: - Public
    // MARK: - Private
}
