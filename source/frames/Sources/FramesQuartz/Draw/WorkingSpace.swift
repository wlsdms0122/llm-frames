//
//  WorkingSpace.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage

// The sRGB working space every picture is drawn, filtered and blended in, on its encoded values, and the one Core
// Image context that works in it.
enum WorkingSpace {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    static let context = CIContext(options: [
        .workingColorSpace: colorSpace,
        .workingFormat: CIFormat.RGBAf,
        .outputColorSpace: colorSpace,
        .cacheIntermediates: false
    ])

    // Sixteen bit premultiplied RGBA in the machine's byte order, as a bitmap holds it.
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
}
