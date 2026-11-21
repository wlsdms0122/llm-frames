//
//  ShapingProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Lists faces and shapes runs of text. frames chooses faces and breaks, wraps and places the lines.
package protocol ShapingProvider: Sendable {
    // The faces of `family` that `files`, a pack's font files, hold.
    func faces(
        family: String,
        in files: [String]
    ) -> [FontFace]

    // The face whose PostScript name is `name` in the font file `file`.
    func face(
        named name: String,
        in file: String
    ) -> FontFace?

    // The faces of `family` installed on the machine.
    func installedFaces(family: String) -> [FontFace]

    // `text` set at `size` with `features` over the font's defaults, its glyphs in glyph order, each with its advance,
    // its placement offset from the pen and the index of the scalar it was set from. Each grapheme cluster is set
    // whole in the first of `faces` that has every scalar of it but its default ignorable ones, and one none of them
    // has whole in a face the provider finds on the machine for `weight` and `italic`, each run with the face it was
    // set in. A face its file does not hold stops.
    func shape(
        _ text: String,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) throws -> [ShapedRun]
}
