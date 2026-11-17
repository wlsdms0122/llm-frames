//
//  ImageTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// An image file an encoder writes from one bitmap, scaled to `size`. A PNG is lossless. A JPEG or HEIC is written at
// its quality's `imageQuality`, and a JPEG, which has no alpha, has its transparent parts on white.
package enum ImageTarget: Equatable, Sendable {
    case png(path: String, size: Size)
    case jpeg(path: String, size: Size, quality: EncodeQuality)
    case heic(path: String, size: Size, quality: EncodeQuality)

    // MARK: - Property
    package var path: String {
        switch self {
        case let .png(path, _), let .jpeg(path, _, _), let .heic(path, _, _):
            path
        }
    }

    package var size: Size {
        switch self {
        case let .png(_, size), let .jpeg(_, size, _), let .heic(_, size, _):
            size
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
