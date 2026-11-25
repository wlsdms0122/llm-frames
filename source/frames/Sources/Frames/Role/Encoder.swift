//
//  Encoder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes rendered frames, mixed sound and transcoded media to files. Nothing a file was read from is copied into it
// but its pixels and samples.
package protocol Encoder: Sendable {
    // Refuses a target the encoder cannot write, naming what it lacks and the file. Everything a write of the target
    // would refuse on the target alone is refused here, before a caller removes an existing file, and a write takes
    // only a target that passed its check. A compressed video's sound depends on the sound, so it is checked as a
    // sound target of the same path and quality.
    func check(_ target: EncodeTarget) throws

    func check(_ target: ImageTarget) throws

    func check(_ target: SoundTarget) throws

    // The analysis picture of `frame`, working values of a sequence whose output `output` encodes, as an 8-bit PNG
    // tagged sRGB: each channel clipped to 0 to 1, a frame of an HDR space encoded as its output and tone mapped from
    // its peak first (FRAMES-26).
    func writeAnalysisPicture(
        of frame: Bitmap,
        in output: ColorConversion,
        to path: String
    ) throws

    // How the image was written (FRAMES-23 Runs).
    @discardableResult
    func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws -> FileEncoding

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
