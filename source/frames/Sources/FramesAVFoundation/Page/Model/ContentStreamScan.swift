//
//  ContentStreamScan.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/22/26.
//

import CoreGraphics

// A content stream as the page walk reads it: the stream, the resources it resolves names with, and the graphics
// state it starts in. These decide all a scan of the stream finds, so a stream is scanned once for each.
struct ContentStreamScan: Hashable {
    // MARK: - Property
    let stream: CGPDFDictionaryRef
    let resources: CGPDFDictionaryRef
    let state: PageGraphicsState

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
