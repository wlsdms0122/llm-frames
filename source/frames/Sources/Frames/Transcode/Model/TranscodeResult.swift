//
//  TranscodeResult.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A file a transcode wrote: its path, its size in bytes and its format, beside the size of the file it was made from.
package struct TranscodeResult: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let byteCount: Int
    package let sourceByteCount: Int
    package let format: TranscodeFormat

    // The output's size over the source's.
    package var ratio: Double {
        Double(byteCount) / Double(sourceByteCount)
    }

    package var isSmaller: Bool {
        byteCount < sourceByteCount
    }

    // MARK: - Initializer
    package init(
        path: String,
        byteCount: Int,
        sourceByteCount: Int,
        format: TranscodeFormat
    ) {
        self.path = path
        self.byteCount = byteCount
        self.sourceByteCount = sourceByteCount
        self.format = format
    }

    // MARK: - Public
    // MARK: - Private
}
