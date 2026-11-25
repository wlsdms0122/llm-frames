//
//  MediumReading.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a decoder read the pictures of one medium by one conversion over a run (FRAMES-23 Runs): the medium's pinned
// path, the directory of an image sequence, and its page, nil for a medium that is no page of a PDF; the conversion to
// working values; how the decoder is given a picture's stored values, `<bits>-bit <integer | float> <channels>`; the
// pictures it gave and decoded; and the times it opened a reader on the medium again after its first.
package struct MediumReading: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let page: Int?
    package let conversion: WorkingConversion
    package let pixelFormat: String
    package let framesRead: Int
    package let framesDecoded: Int
    package let reopened: Int

    // MARK: - Initializer
    package init(
        path: String,
        page: Int?,
        conversion: WorkingConversion,
        pixelFormat: String,
        framesRead: Int,
        framesDecoded: Int,
        reopened: Int
    ) {
        self.path = path
        self.page = page
        self.conversion = conversion
        self.pixelFormat = pixelFormat
        self.framesRead = framesRead
        self.framesDecoded = framesDecoded
        self.reopened = reopened
    }

    // MARK: - Public
    // MARK: - Private
}
