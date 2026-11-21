//
//  DocumentWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames

// Writes a PDF through Core Graphics, one page of each size in points, each drawn by a test on a canvas whose media
// pixels are the page's points. Core Graphics embeds the fonts the text is drawn in.
package struct DocumentWriter {
    // MARK: - Property
    private let sizes: [Size]

    // MARK: - Initializer
    package init(sizes: [Size]) {
        self.sizes = sizes
    }

    // MARK: - Public
    // `drawing` draws page `index`, from 0.
    package func write(
        to path: String,
        drawing: (Int, Canvas) -> Void
    ) throws {
        var box = CGRect(x: 0, y: 0, width: sizes.first?.width ?? 1, height: sizes.first?.height ?? 1)
        guard let context = CGContext(URL(fileURLWithPath: path) as CFURL, mediaBox: &box, nil) else {
            throw TestMediaError.unwritable(path)
        }

        for (index, size) in sizes.enumerated() {
            var page = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            let info = [kCGPDFContextMediaBox as String: Data(bytes: &page, count: MemoryLayout<CGRect>.size)]
            context.beginPDFPage(info as CFDictionary)
            drawing(index, Canvas(context: context, size: size))
            context.endPDFPage()
        }
        context.closePDF()
    }

    // MARK: - Private
}
