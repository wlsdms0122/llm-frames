//
//  OCRProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Recognises text in a media file through the decoder. What makes one line is the provider's.
protocol OCRProvider: Sendable {
    // The lines on the frame of `file` (a media file or an image sequence directory) shown at media time `time`. A
    // still has one frame.
    func lines(
        in file: String,
        atMediaTime time: Double
    ) throws -> [RecognisedLine]
}
