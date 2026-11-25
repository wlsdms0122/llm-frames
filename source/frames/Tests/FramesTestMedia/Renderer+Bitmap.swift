//
//  Renderer+Bitmap.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/25/26.
//

import Frames

extension Renderer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The list's frame as a bitmap, a surface's read where it lies.
    package func bitmap(of list: DisplayList) throws -> Bitmap {
        try frame(of: list).bitmap
    }

    // MARK: - Private
}
