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

    // `text`, a shaping run of one run's text at one embedding level and one orientation, set in `direction` at `size`
    // with `features` over the font's defaults, and reordered by nothing else. Its glyphs are given in the order they
    // lie along the line from left to right, for a right-to-left run the reverse of the order it is read in, each with
    // its advance, its placement offset from the pen and the index of the scalar it was set from, and a character with
    // the `Bidi_Mirrored` property is set in its mirrored glyph in a right-to-left run. An `upright` run is set upright
    // in a vertical line, left to right being top to bottom: in the vertical forms of its faces that `features` leave
    // on, its horizontal forms where `vert` and `vrt2` are 0, each glyph with its vertical advance and the move from
    // the pen at its vertical origin to its origin in its placement offset, the vertical metrics of a face without any
    // made from its ascent and descent. Any other run is set as horizontal text, whatever line it lies in. Each
    // grapheme cluster is set whole in the first of `faces` that has every scalar of it but its default ignorable
    // ones, and one none of them has whole in a face the provider finds on the machine for `weight` and `italic`, each
    // run with the face it was set in, the runs in the order they lie on the line. A face its file does not hold
    // stops.
    func shape(
        _ text: String,
        direction: TextDirection,
        upright: Bool,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) throws -> [ShapedRun]
}
