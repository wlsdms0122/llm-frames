//
//  UnsafeMutableBufferPointer+Zeroed.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

extension UnsafeMutableBufferPointer where Element == Double {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A new buffer of `count` zeros, which its owner deallocates.
    static func zeroed(_ count: Int) -> Self {
        let buffer = allocate(capacity: count)
        buffer.initialize(repeating: 0)

        return buffer
    }

    // MARK: - Private
}
