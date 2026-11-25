//
//  PictureItem+Composite.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import Frames

extension PictureItem {
    // MARK: - Property
    // Whether the picture draws its source cut to its destination with its corners rounded, under its border and over
    // its shadow, and nothing more: no filter, transition matte or corner pin.
    var showsSourceFramed: Bool {
        filter.isEmpty && matte == nil && cornerPin == nil
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
