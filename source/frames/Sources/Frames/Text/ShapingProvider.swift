//
//  ShapingProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds faces and shapes runs of text. frames breaks, wraps and places the lines.
package protocol ShapingProvider: Sendable {
    // The face of `family` in `weight` that one of `files`, a pack's font files, holds.
    func face(
        family: String,
        weight: FontWeight,
        in files: [String]
    ) -> FontFace?

    // The face of `family` in `weight` installed on the machine.
    func installedFace(
        family: String,
        weight: FontWeight
    ) -> FontFace?

    // `text` set in `face` at `size`, in order. Characters the face lacks are set in a face the provider finds on the
    // machine, each run with the face it was set in. A face its file does not hold stops.
    func shape(
        _ text: String,
        face: FontFace,
        size: Double
    ) throws -> [ShapedRun]
}
