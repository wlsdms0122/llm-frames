//
//  TrackTarget.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The target `track` follows, as the JSON text its option gives (FRAMES-23): a rect area `[x, y, w, h]` from `--area`,
// or from `--quad` four points `[x, y]`, its top left, top right, bottom right and bottom left corners, the order a
// corner pin writes its points in.
package enum TrackTarget: Equatable, Sendable {
    case area(String)
    case quad(String)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
