//
//  PDFValue.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// A PDF object (ISO 32000-1 7.3) as `PDFFileWriter` writes it. A stream holds its dictionary and its data, written
// unfiltered, and `reference` names an object of the file being written.
indirect enum PDFValue: Hashable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int)
    case real(Double)
    case name(String)
    case string(Data)
    case array([PDFValue])
    case dictionary([String: PDFValue])
    case stream([String: PDFValue], Data)
    case reference(Int)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
