//
//  TrackFacts.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreMedia
import Foundation

// What AVFoundation loads of a video's picture track and its file. `edits` map the times the track's samples carry
// onto the file's presentation timeline, without the empty edits, and `duration` is the file's on that timeline.
struct TrackFacts: Sendable {
    // MARK: - Property
    let storedSize: CGSize
    let preferredTransform: CGAffineTransform
    let nominalFrameRate: Float
    let bitsPerComponent: Int
    let hasAlpha: Bool
    let edits: [CMTimeMapping]
    let duration: CMTime
    let hasSound: Bool

    // MARK: - Initializer
    init(
        storedSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        bitsPerComponent: Int,
        hasAlpha: Bool,
        edits: [CMTimeMapping],
        duration: CMTime,
        hasSound: Bool
    ) {
        self.storedSize = storedSize
        self.preferredTransform = preferredTransform
        self.nominalFrameRate = nominalFrameRate
        self.bitsPerComponent = bitsPerComponent
        self.hasAlpha = hasAlpha
        self.edits = edits
        self.duration = duration
        self.hasSound = hasSound
    }

    // MARK: - Public
    // MARK: - Private
}
