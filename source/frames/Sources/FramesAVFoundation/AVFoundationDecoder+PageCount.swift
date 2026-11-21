//
//  AVFoundationDecoder+PageCount.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames

extension AVFoundationDecoder {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A file Core Graphics opens as a PDF document is a PDF, of the pages that document holds.
    package func pageCount(of file: String) throws -> Int? {
        guard FileManager.default.fileExists(atPath: file) else { return nil }

        return CGPDFDocument(URL(fileURLWithPath: file) as CFURL)?.numberOfPages
    }

    // MARK: - Private
}
