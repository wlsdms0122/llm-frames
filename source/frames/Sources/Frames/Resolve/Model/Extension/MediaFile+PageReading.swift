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
    // The colour space a page refuses of a reading in `colorSpace`: a page is not HDR, so it is read only in a space of
    // standard dynamic range (FRAMES-26 Media). Nil for a reading it takes, and for a file that is no page. A place
    // that reads a page and no `toneMap`, a transition's cover and matte and `ocr`, asks here.
    func pageRefusedColorSpace(_ colorSpace: ColorSpace?) -> ColorSpace? {
        guard page != nil, let colorSpace, colorSpace.isHighDynamicRange else { return nil }

        return colorSpace
    }

    // What a page refuses of a reading in `colorSpace` with `toneMap` written as `isToneMapped`: a page takes no
    // `toneMap` and refuses the colour spaces `pageRefusedColorSpace(_:)` names (FRAMES-26 Media). Nil for a reading it
    // takes, and for a file that is no page. A place that reads a page and its `toneMap`, a clip and a template's
    // argument, asks here.
    func pageRefusal(
        colorSpace: ColorSpace?,
        isToneMapped: Bool?
    ) -> PageReadingRefusal? {
        guard page != nil else { return nil }
        guard isToneMapped == nil else { return .toneMap }

        return pageRefusedColorSpace(colorSpace).map(PageReadingRefusal.colorSpace)
    }

    // MARK: - Private
}
