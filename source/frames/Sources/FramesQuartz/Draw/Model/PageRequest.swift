//
//  PageRequest.swift
//  FramesQuartz
//
//  Created by JSilver on 11/21/26.
//

import Frames

// What a picture of a page of a PDF is read by: the page, the region of its grid, the scale and the reading.
struct PageRequest: Equatable {
    // MARK: - Property
    let page: Int?
    let region: PageRegion
    let scale: Double
    let reading: PictureReading

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
