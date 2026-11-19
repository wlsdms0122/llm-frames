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
    // of alpha 0 stays 0.
    package func convertColors(by conversion: (RGB) -> RGB) {
        for offset in stride(from: 0, to: count - 3, by: 4) {
            let alpha = Double(self[offset + 3])
            guard alpha > 0 else {
                self[offset] = 0
                self[offset + 1] = 0
                self[offset + 2] = 0
                continue
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

    // MARK: - Private
}
