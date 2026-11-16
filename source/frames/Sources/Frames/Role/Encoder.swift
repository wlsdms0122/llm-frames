//
//  Encoder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes rendered frames, mixed sound and transcoded media to files. Nothing a file was read from is copied into it
// but its pixels and samples.
package protocol Encoder: Sendable {
    // Refuses a target the encoder cannot write, naming what it lacks and the file.
    func check(_ target: EncodeTarget) throws

    func check(_ target: ImageTarget) throws

    func check(_ target: SoundTarget) throws

    // A PNG tagged sRGB.
    func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws

    func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws

    // `sound` is the whole file's.
    func writeSound(
        _ sound: SoundBuffer,
        for target: SoundTarget
    ) throws

    // `size` is the frames' appended, which a compressed target scales to its own. `sound`, when given, is the whole
    // output's, so the writer interleaves it with the frames as they arrive.
    func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter
}
