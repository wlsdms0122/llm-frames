//
//  ProbedColorSpace.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The colour facts of a picture as `probe` reports them (FRAMES-23): `name` is the space of the table the decoder takes
// the picture in, `srgb` when it is untagged and nil when it is tagged outside the table, and `primaries`,
// `transfer` and `matrix` the H.273 code points it is tagged with, nil for one it leaves out. An image tagged by an
// ICC profile gives those of the table's row the profile describes, nil outside the table, and no matrix.
// `bitDepth` is the bits per channel the file stores, and `isHighDynamicRange` says whether its transfer is PQ or HLG.
package struct ProbedColorSpace: Equatable, Sendable {
    // MARK: - Property
    package let name: ColorSpace?
    package let primaries: Int?
    package let transfer: Int?
    package let matrix: Int?
    package let bitDepth: Int
    package let isHighDynamicRange: Bool

    // MARK: - Initializer
    package init(
        name: ColorSpace?,
        primaries: Int?,
        transfer: Int?,
        matrix: Int?,
        bitDepth: Int,
        isHighDynamicRange: Bool
    ) {
        self.name = name
        self.primaries = primaries
        self.transfer = transfer
        self.matrix = matrix
        self.bitDepth = bitDepth
        self.isHighDynamicRange = isHighDynamicRange
    }

    // MARK: - Public
    // MARK: - Private
}
