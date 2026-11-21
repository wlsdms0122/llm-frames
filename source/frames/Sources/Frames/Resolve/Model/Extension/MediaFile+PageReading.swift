//
//  MediaFile+PageReading.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // What a page refuses of a reading in `colorSpace` with `toneMap` written as `isToneMapped`: a page is not HDR, so
    // it is read only in a space of standard dynamic range and takes no `toneMap` (FRAMES-26 Media). Nil for a reading
    // it takes, and for a file that is no page. Every place that reads a page, a clip, a template's argument, a
    // transition's cover and matte and `ocr`, asks here.
    func pageRefusal(
        colorSpace: ColorSpace?,
        isToneMapped: Bool?
    ) -> PageReadingRefusal? {
        guard page != nil else { return nil }
        guard isToneMapped == nil else { return .toneMap }
        guard let colorSpace, colorSpace.isHighDynamicRange else { return nil }

        return .colorSpace(colorSpace)
    }

    // MARK: - Private
}
