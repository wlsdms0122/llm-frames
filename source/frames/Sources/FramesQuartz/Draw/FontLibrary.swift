//
//  FontLibrary.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreText
import Foundation
import os

// The faces glyphs are drawn in, read from their font files and kept. A face is named by its PostScript name within
// its file, as the `coretext` shaper names it, so a collection file gives the one face of that name.
final class FontLibrary: Sendable {
    // MARK: - Property
    private let descriptors = OSAllocatedUnfairLock<[String: CTFontDescriptor]>(uncheckedState: [:])

    // MARK: - Initializer
    init() {}

    // MARK: - Public
    func font(
        file: String,
        face: String,
        size: Double
    ) throws -> CTFont {
        CTFontCreateWithFontDescriptor(try descriptor(file: file, face: face), size, nil)
    }

    // MARK: - Private
    private func descriptor(
        file: String,
        face: String
    ) throws -> CTFontDescriptor {
        let key = file + "\u{0}" + face
        if let descriptor = descriptors.withLockUnchecked({ $0[key] }) { return descriptor }

        let found = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: file) as CFURL) as? [CTFontDescriptor]
        let named = found?.first { descriptor in
            CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String == face
        }
        guard let named else { throw QuartzError.faceNotInFile(file: file, face: face) }
        descriptors.withLockUnchecked { $0[key] = named }

        return named
    }
}
