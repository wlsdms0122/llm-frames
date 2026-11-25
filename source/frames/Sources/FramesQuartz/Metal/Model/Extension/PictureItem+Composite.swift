//
//  PictureItem+Composite.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import Frames

extension PictureItem {
    // MARK: - Property
    // Whether the picture draws from its source alone: filtered, cut to its destination with its corners rounded,
    // under its border and over its shadow, with no transition matte or corner pin.
    var drawsSourceAlone: Bool {
        matte == nil && cornerPin == nil
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
