//
//  QuartzRenderer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The `quartz` renderer: draws display lists with Core Graphics and Core Image in the sRGB working space, reading
// media pictures through the decoder.
package final class QuartzRenderer: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
}

extension QuartzRenderer: Renderer {
    // MARK: - Lifecycle
    package func check(_ list: DisplayList) throws {
        throw QuartzError.notImplemented
    }

    package func frame(of list: DisplayList) throws -> Bitmap {
        throw QuartzError.notImplemented
    }
}
