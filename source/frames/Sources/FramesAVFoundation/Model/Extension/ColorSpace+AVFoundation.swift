//
//  ColorSpace+AVFoundation.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import AVFoundation
import CoreVideo
import Frames

// A colour space as AVFoundation tags it: the H.273 code points of FRAMES-26 as Core Video names them in a video. Core
// Video names transfer 14 `ITU_R_2020`, and its integer mapping folds 14 into BT.709's 1, so the names are spelled out
// here.
extension ColorSpace {
    // MARK: - Property
    // The colour properties of a video's settings, which its frames' attachments repeat.
    var videoColorProperties: [String: String] {
        let points = codePoints

        return [
            AVVideoColorPrimariesKey: Self.primariesName(points.colorPrimaries),
            AVVideoTransferFunctionKey: Self.transferName(points.transferCharacteristics),
            AVVideoYCbCrMatrixKey: Self.matrixName(points.matrixCoefficients)
        ]
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func primariesName(_ code: Int) -> String {
        switch code {
        case 9:
            AVVideoColorPrimaries_ITU_R_2020

        case 12:
            AVVideoColorPrimaries_P3_D65

        default:
            AVVideoColorPrimaries_ITU_R_709_2
        }
    }

    private static func transferName(_ code: Int) -> String {
        switch code {
        case 13:
            kCVImageBufferTransferFunction_sRGB as String

        case 14:
            kCVImageBufferTransferFunction_ITU_R_2020 as String

        case 16:
            AVVideoTransferFunction_SMPTE_ST_2084_PQ

        case 18:
            AVVideoTransferFunction_ITU_R_2100_HLG

        default:
            AVVideoTransferFunction_ITU_R_709_2
        }
    }

    private static func matrixName(_ code: Int) -> String {
        code == 9 ? AVVideoYCbCrMatrix_ITU_R_2020 : AVVideoYCbCrMatrix_ITU_R_709_2
    }
}
