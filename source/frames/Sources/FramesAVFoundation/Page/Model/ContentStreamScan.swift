//
//  ContentStreamScan.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/22/26.
//

import CoreGraphics

// A content stream as the page walk reads it: the stream, the resources it resolves names with, the graphics state it
// starts in, whether optional content hides it, where nothing it draws is checked, and whether it is an uncoloured
// pattern's content, where the colours it sets are not drawn. These decide all a scan of the stream records, so a
// stream is scanned once for each.
struct ContentStreamScan: Hashable {
    // MARK: - Property
    let stream: CGPDFDictionaryRef
    let resources: CGPDFDictionaryRef
    let state: PageGraphicsState
    let isHidden: Bool
    let isUncolored: Bool

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
