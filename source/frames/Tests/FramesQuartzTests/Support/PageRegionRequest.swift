//
//  PageRegionRequest.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import Frames

// A region of a page's grid and the scale a decoder is asked for it at.
struct PageRegionRequest: Equatable, CustomStringConvertible {
    // MARK: - Property
    let region: PageRegion
    let scale: Double

    var description: String {
        "[\(region.x), \(region.y), \(region.width), \(region.height)] at \(scale)"
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
