//
//  TrackMatteMode.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What of a track matte's picture a clip's alpha is multiplied by: its alpha, or its luma, the Rec. 709 luma of its
// unpremultiplied sRGB-encoded values times its alpha, so a transparent part of a luma matte counts as black.
package enum TrackMatteMode: String, CaseIterable, Equatable, Sendable {
    case alpha
    case luma

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
