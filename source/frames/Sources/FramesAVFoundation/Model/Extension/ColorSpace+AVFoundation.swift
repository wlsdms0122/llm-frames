//
//  ColorSpace+AVFoundation.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import AVFoundation
import CoreGraphics
import CoreVideo
import Frames

// A colour space as AVFoundation and Core Graphics tag it: the H.273 code points of FRAMES-26 as Core Video names them
// in a video, and the Core Graphics space whose ICC profile an image carries. ImageIO writes the `srgb` space of a PNG
// as an sRGB chunk. Core Video names transfer 14 `ITU_R_2020`, and its integer mapping folds 14 into BT.709's 1, so the
// names are spelled out here. Core Graphics' `itur_709` and `itur_2020` spaces carry the BT.709 OETF, so `rec709` and
// `rec2020` images carry a matrix profile of their primaries and BT.1886's EOTF at a black of 0, a gamma of 2.4, as
// `TransferFunction.bt1886` decodes.
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

    var imageSpace: CGColorSpace {
        switch self {
        case .srgb:
            Self.srgbImageSpace

        case .displayP3:
            Self.displayP3ImageSpace

        case .rec2020:
            Self.rec2020ImageSpace

        case .rec709:
            Self.rec709ImageSpace

        case .rec2100PQ:
            Self.rec2100PQImageSpace

        case .rec2100HLG:
            Self.rec2100HLGImageSpace
        }
    }

    private static let srgbImageSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let displayP3ImageSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    private static let rec2020ImageSpace = bt1886Space(of: ColorSpace.rec2020.primaries)
    private static let rec709ImageSpace = bt1886Space(of: ColorSpace.rec709.primaries)
    private static let rec2100PQImageSpace = CGColorSpace(name: CGColorSpace.itur_2100_PQ)!
    private static let rec2100HLGImageSpace = CGColorSpace(name: CGColorSpace.itur_2100_HLG)!

    // MARK: - Initializer
    // The space of an image tagged with a Core Graphics space `imageSpace` gives, by its name or its ICC profile, or else
    // the space of the table the profile's `cicp` tag (ICC.1 v4.4) names; nil for any other. ImageIO reads an HDR HEIC
    // with a profile of its own, which keeps the `cicp` tag of the space written and adds HDR metadata.
    init?(imageSpace: CGColorSpace) {
        let profile = imageSpace.copyICCData() as Data?
        let match = Self.allCases.first { space in
            if let name = imageSpace.name, name == space.imageSpace.name { return true }

            return profile != nil && profile == space.imageSpace.copyICCData() as Data?
        }
        if let match {
            self = match
            return
        }
        guard let codePoints = profile.flatMap(Self.cicpCodePoints(of:)) else { return nil }

        self.init(colorPrimaries: codePoints.colorPrimaries, transferCharacteristics: codePoints.transferCharacteristics)
    }

    // MARK: - Public
    // MARK: - Private
    // A calibrated RGB space of `primaries` at the D65 white of FRAMES-26 whose curve is BT.1886's EOTF.
    private static func bt1886Space(of primaries: ColorPrimaries) -> CGColorSpace {
        let white = ColorPrimaries.whitePoint
        let toXYZ = ColorMatrix(normalizedPrimaryOf: primaries).rows
        // Core Graphics takes the columns, the XYZ of red, green and blue, one after another.
        let matrix = (0..<3).flatMap { column in (0..<3).map { row in CGFloat(toXYZ[row][column]) } }

        return CGColorSpace(
            calibratedRGBWhitePoint: [white.x / white.y, 1, (1 - white.x - white.y) / white.y],
            blackPoint: [0, 0, 0],
            gamma: [2.4, 2.4, 2.4],
            matrix: matrix
        )!
    }

    // The colour primaries and transfer characteristics of a profile's `cicp` tag, nil for a profile without one. The
    // tag table follows the 128-byte header, its numbers big-endian.
    private static func cicpCodePoints(of profile: Data) -> (colorPrimaries: Int, transferCharacteristics: Int)? {
        let bytes = [UInt8](profile)
        func number(at offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
        }
        guard bytes.count >= 132 else { return nil }

        let tagCount = number(at: 128)
        for tag in 0..<tagCount {
            let entry = 132 + tag * 12
            guard bytes.count >= entry + 12 else { return nil }
            guard String(decoding: bytes[entry..<entry + 4], as: UTF8.self) == "cicp" else { continue }

            let element = number(at: entry + 4)
            guard bytes.count >= element + 12 else { return nil }

            return (Int(bytes[element + 8]), Int(bytes[element + 9]))
        }

        return nil
    }

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
