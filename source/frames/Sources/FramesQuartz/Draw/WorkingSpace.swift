//
//  WorkingSpace.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// The two forms of the working values (FRAMES-26) as Core Graphics colour spaces, extended sRGB for the encoded form
// and extended linear sRGB for the linear one, and a Core Image context working in each. A list is drawn in the form
// its `compositing` names, so Core Graphics composites, covers edges and resamples in it, and Core Image blurs and
// mixes in it; a formula with a home of its own converts to that home inside its kernel.
enum WorkingSpace {
    static let encoded = CGColorSpace(name: CGColorSpace.extendedSRGB)!
    static let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!

    private static let encodedContext = makeContext(working: encoded, format: .RGBAh)
    private static let linearContext = makeContext(working: linear, format: .RGBAh)

    // A context in 32 bit float on the encoded form for values that are not colours: mask coverage and a track
    // matte's value, which takes luma on the encoded form.
    static let valueContext = makeContext(working: encoded, format: .RGBAf)

    // Half float premultiplied RGBA in the machine's byte order, as a frame holds it.
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.floatComponents.rawValue
        | CGBitmapInfo.byteOrder16Little.rawValue

    static func colorSpace(of compositing: Compositing) -> CGColorSpace {
        switch compositing {
        case .encoded:
            encoded

        case .linear:
            linear
        }
    }

    static func context(of compositing: Compositing) -> CIContext {
        switch compositing {
        case .encoded:
            encodedContext

        case .linear:
            linearContext
        }
    }

    private static func makeContext(
        working space: CGColorSpace,
        format: CIFormat
    ) -> CIContext {
        CIContext(options: [
            .workingColorSpace: space,
            .workingFormat: format,
            .outputColorSpace: encoded,
            .cacheIntermediates: false
        ])
    }
}

extension Compositing {
    // The argument a kernel takes for the form its samples are in: 1 for the linear form and 0 for the encoded one.
    var kernelArgument: Double {
        self == .linear ? 1 : 0
    }
}
