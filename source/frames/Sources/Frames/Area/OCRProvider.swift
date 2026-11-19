//
//  OCRProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Recognises text in a media file through the decoder. What makes one line is the provider's.
package protocol OCRProvider: Sendable {
    // The lines on the frame of `file` (a media file or an image sequence directory) shown at media time `time`. A
    // still has one frame. `languages` are the recognition languages in order of preference, and nil has the provider
    // detect the language of the picture. The frame is read as an analysis picture, in `colorSpace` where one is given
    // and as the file's tags say otherwise. A provider refuses before it reads the frame on a tag it cannot recognise,
    // naming it.
    func lines(
        in file: MediaFile,
        atMediaTime time: Double,
        languages: [LanguageTag]?,
        colorSpace: ColorSpace?
    ) throws -> [RecognisedLine]
}
