//
//  UnsafeMutableBufferPointer+Color.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// Interleaved RGBA pixels with premultiplied alpha, as a picture holds them.
extension UnsafeMutableBufferPointer where Element == Float {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Each pixel's colour unpremultiplied, converted by `conversion` and premultiplied again, its alpha kept. A pixel
    // of alpha 0 stays 0. `conversion` is a pure function, so a pixel whose four samples have the bits of the pixel
    // before it takes that pixel's result without converting it again: a run of one colour converts once.
    package func convertColors(by conversion: (RGB) -> RGB) {
        guard let base = baseAddress, count >= 4 else { return }

        // A pixel's four samples compare as two 64-bit words, which costs less than one vector comparison.
        let bytes = UnsafeRawPointer(base)
        var previous = Self.words(at: 0, of: bytes)
        convert(at: 0, by: conversion)
        for offset in stride(from: 4, to: count - 3, by: 4) {
            let samples = Self.words(at: offset, of: bytes)
            guard samples != previous else {
                self[offset] = self[offset - 4]
                self[offset + 1] = self[offset - 3]
                self[offset + 2] = self[offset - 2]
                continue
            }

            previous = samples
            convert(at: offset, by: conversion)
        }
    }

    // MARK: - Private
    // The samples of the pixel at `offset` as two 64-bit words.
    private static func words(
        at offset: Int,
        of bytes: UnsafeRawPointer
    ) -> (UInt64, UInt64) {
        let start = offset * MemoryLayout<Float>.stride

        return (
            bytes.loadUnaligned(fromByteOffset: start, as: UInt64.self),
            bytes.loadUnaligned(fromByteOffset: start + 8, as: UInt64.self)
        )
    }

    private func convert(
        at offset: Int,
        by conversion: (RGB) -> RGB
    ) {
        let alpha = Double(self[offset + 3])
        guard alpha > 0 else {
            self[offset] = 0
            self[offset + 1] = 0
            self[offset + 2] = 0
            return
        }

        let converted = conversion(RGB(
            red: Double(self[offset]) / alpha,
            green: Double(self[offset + 1]) / alpha,
            blue: Double(self[offset + 2]) / alpha
        ))
        self[offset] = Float(converted.red * alpha)
        self[offset + 1] = Float(converted.green * alpha)
        self[offset + 2] = Float(converted.blue * alpha)
    }
}
