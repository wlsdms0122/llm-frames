//
//  TranscodeLine.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// The line `transcode` prints: the output's path, size and format, and its size as a percentage of the source's with
// one decimal and the source's size, as `/abs/out.mp4  1.2 MB  H.264 with AAC  42.0% of 2.9 MB`. An output that is
// not smaller says so at the end, since a transcode is asked for to shrink a file.
struct TranscodeLine: Equatable, CustomStringConvertible, Sendable {
    // MARK: - Property
    let result: TranscodeResult

    var description: String {
        let size = FileSize(bytes: Int64(result.byteCount))
        let source = FileSize(bytes: Int64(result.sourceByteCount))
        let percentage = String(format: "%.1f%%", result.ratio * 100)
        let line = "\(result.path)  \(size)  \(result.format.name)  \(percentage) of \(source)"

        return result.isSmaller ? line : line + ", not smaller than the source"
    }

    // MARK: - Initializer
    init(_ result: TranscodeResult) {
        self.result = result
    }

    // MARK: - Public
    // MARK: - Private
}
