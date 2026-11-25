//
//  ReadingTally.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Frames

// What the decoder has read of one medium by one conversion: how it is given the stored values, the pictures it gave
// and decoded, the times it opened a reader on the medium again, and the files of a still or an image sequence it has
// read, by which a read of one again is a reopening.
struct ReadingTally: Sendable {
    // MARK: - Property
    let order: Int
    var pixelFormat: String
    var framesRead = 0
    var framesDecoded = 0
    var reopened = 0
    var filesRead: Set<String> = []

    // MARK: - Initializer
    init(
        order: Int,
        pixelFormat: String
    ) {
        self.order = order
        self.pixelFormat = pixelFormat
    }

    // MARK: - Public
    // MARK: - Private
}
