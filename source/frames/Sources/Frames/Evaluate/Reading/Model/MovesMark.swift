//
//  MovesMark.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// How a written member of a display item may differ between the sample lists of one frame, by the Moves columns of
// FRAMES-20.
indirect enum MovesMark: Sendable {
    // Equal in every sample.
    case fixed
    // Any value in each sample.
    case moves
    // `null` in every sample, or an object with the same keys in each, each member by its mark and by `other` where it
    // has none.
    case members([String: MovesMark], other: MovesMark)
    // `null` in every sample, or a list of the same length in each, each element by the mark.
    case elements(MovesMark)
    // A list of the same length in every sample, each element by the mark at its index, and equal past the marks.
    case tuple([MovesMark])
    // A list of display items of the same length in every sample, each item by the marks of its kind.
    case items

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
