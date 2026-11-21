//
//  QuartzRenderer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The `quartz` renderer: draws display lists with Core Graphics and Core Image on the working values of FRAMES-26, each
// list in the form its `compositing` names, reading media pictures through the decoder at any bit depth, and a list
// given as sample lists as the mean of their pictures. A frame is a half float premultiplied RGBA bitmap of encoded
// working values, unbounded, of the list's size.
package final class QuartzRenderer: Sendable {
    // MARK: - Property
    private let pictures: MediaPictureCache
    private let tables = LookUpTableCache()
    private let fonts = FontLibrary()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.pictures = MediaPictureCache(decoder: decoder)
    }

    // MARK: - Public
    // MARK: - Private
}

extension QuartzRenderer: Renderer {
    // MARK: - Lifecycle
    package func check(_ list: DisplayList) throws {
        try DisplayListChecker(tables: tables).check(list)
    }

    package func frame(of list: DisplayList) throws -> Bitmap {
        try FrameDrawer(pictures: pictures, tables: tables, fonts: fonts).draw(list).bitmap()
    }
}
