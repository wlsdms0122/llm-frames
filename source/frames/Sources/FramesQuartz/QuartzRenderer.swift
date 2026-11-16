//
//  QuartzRenderer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The `quartz` renderer: draws display lists with Core Graphics and Core Image in the sRGB working space, reading
// media pictures through the decoder. A frame is a sixteen bit premultiplied RGBA bitmap of the list's size.
package final class QuartzRenderer: Sendable {
    // MARK: - Property
    private let pictures: MediaPictureCache
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
        try DisplayListChecker().check(list)
    }

    package func frame(of list: DisplayList) throws -> Bitmap {
        try FrameDrawer(pictures: pictures, fonts: fonts).draw(list).bitmap()
    }
}
