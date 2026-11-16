//
//  Encoder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes rendered frames and mixed sound to files.
package protocol Encoder: Sendable {
    // Refuses a target the encoder cannot write, naming what it lacks and the file.
    func check(_ target: EncodeTarget) throws

    // A PNG tagged sRGB.
    func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws

    // `sound`, when given, is the whole output's, so the writer interleaves it with the frames as they arrive.
    func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter
}
