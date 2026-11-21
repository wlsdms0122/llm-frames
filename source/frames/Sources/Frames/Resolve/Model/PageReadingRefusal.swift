//
//  PageReadingRefusal.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// What a place that reads a page of a PDF writes and a page does not take, since a page is not HDR (FRAMES-26 Media):
// `toneMap`, or a `colorSpace` of HDR range.
enum PageReadingRefusal: Equatable, Sendable {
    case toneMap
    case colorSpace(ColorSpace)
}
