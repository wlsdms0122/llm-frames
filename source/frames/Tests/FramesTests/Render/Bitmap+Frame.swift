//
//  Bitmap+Frame.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

@testable import Frames

// A one pixel bitmap carrying the number of the frame it was drawn for, so a test follows each frame to the writers.
extension Bitmap {
    // MARK: - Property
    var frame: Int {
        pixels.withUnsafeBytes { $0.loadUnaligned(as: Int.self) }
    }

    // MARK: - Initializer
    init(frame: Int) {
        self.init(
            width: 1,
            height: 1,
            depth: .eight,
            bytesPerRow: MemoryLayout<Int>.size,
            pixels: withUnsafeBytes(of: frame) { Data($0) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
