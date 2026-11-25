//
//  PictureItem+Composite.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import Frames

extension PictureItem {
    // MARK: - Property
    // Whether the picture draws its source cut to its destination and nothing more: no filter, transition matte,
    // rounded corner, border, shadow or corner pin.
    var showsSourceAlone: Bool {
        filter.isEmpty && matte == nil && radius == 0 && border == nil && shadow == nil && cornerPin == nil
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
