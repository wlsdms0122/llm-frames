//
//  YCbCrLayout.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import CoreMedia
import CoreVideo
import Foundation

// How a video's frames are given as the Y'CbCr its stream stores, a plane of luma and a plane of interleaved Cb and
// Cr, and taken to R'G'B' (FRAMES-21 Rules): each code value of `bitDepth` bits quantised in the narrow or the full
// range, the matrix of H.273 by its constants KR and KB, and chroma upsampled bilinearly from samples standing at
// `chromaSiting`. A 10-bit sample is held in the high bits of 16.
struct YCbCrLayout: Equatable, Sendable {
    // MARK: - Property
    let bitDepth: Int
    let sampling: ChromaSampling
    let isFullRange: Bool
    let lumaRed: Double
    let lumaBlue: Double
    // The centre of chroma sample (0, 0) in luma pixels, the centre of luma pixel (0, 0) being (0.5, 0.5).
    let chromaSiting: SIMD2<Double>

    var lumaGreen: Double {
        1 - lumaRed - lumaBlue
    }

    // Y' = (D − `lumaOffset`) / `lumaScale` and Cb = (D − `chromaOffset`) / `chromaScale`, as BT.709 and BT.2100
    // quantise them.
    var lumaOffset: Double {
        isFullRange ? 0 : 16 * step
    }

    var lumaScale: Double {
        isFullRange ? maximum : 219 * step
    }

    var chromaOffset: Double {
        isFullRange ? Double(1 << (bitDepth - 1)) : 128 * step
    }

    var chromaScale: Double {
        isFullRange ? maximum : 224 * step
    }

    // The bits a sample is shifted up by in its 16-bit or 8-bit word.
    var shift: Int {
        bitDepth == 10 ? 6 : 0
    }

    var pixelFormat: OSType {
        switch (sampling, bitDepth == 10, isFullRange) {
        case (.fourTwoZero, false, false): kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case (.fourTwoZero, false, true): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        case (.fourTwoZero, true, false): kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case (.fourTwoZero, true, true): kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        case (.fourTwoTwo, false, false): kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange
        case (.fourTwoTwo, false, true): kCVPixelFormatType_422YpCbCr8BiPlanarFullRange
        case (.fourTwoTwo, true, false): kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange
        case (.fourTwoTwo, true, true): kCVPixelFormatType_422YpCbCr10BiPlanarFullRange
        case (.fourFourFour, false, false): kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange
        case (.fourFourFour, false, true): kCVPixelFormatType_444YpCbCr8BiPlanarFullRange
        case (.fourFourFour, true, false): kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange
        case (.fourFourFour, true, true): kCVPixelFormatType_444YpCbCr10BiPlanarFullRange
        }
    }

    // As FRAMES-23 Runs names a pixel format.
    var name: String {
        "\(bitDepth)-bit integer Y'CbCr \(sampling.name)"
    }

    private var step: Double {
        Double(1 << (bitDepth - 8))
    }

    private var maximum: Double {
        Double((1 << bitDepth) - 1)
    }

    // MARK: - Initializer
    init(
        bitDepth: Int,
        sampling: ChromaSampling,
        isFullRange: Bool,
        lumaRed: Double,
        lumaBlue: Double,
        chromaSiting: SIMD2<Double>
    ) {
        self.bitDepth = bitDepth
        self.sampling = sampling
        self.isFullRange = isFullRange
        self.lumaRed = lumaRed
        self.lumaBlue = lumaBlue
        self.chromaSiting = chromaSiting
    }

    // The layout of a stream the decoder takes as Y'CbCr, by its format and the matrix code point it is tagged with,
    // nil where it is given as `16-bit float RGBA` (FRAMES-21 Rules): a stream with alpha, of a codec, profile or
    // depth this lists not, of a matrix with no constants KR and KB, or of the DV 4:2:0 chroma location.
    init?(
        format: CMFormatDescription,
        matrix: Int?,
        hasAlpha: Bool
    ) {
        guard !hasAlpha, let (lumaRed, lumaBlue) = Self.constants(ofMatrix: matrix ?? 2) else { return nil }
        guard let (bitDepth, sampling) = Self.samples(of: format) else { return nil }

        let location = CMFormatDescriptionGetExtension(
            format,
            extensionKey: kCMFormatDescriptionExtension_ChromaLocationTopField
        ) as? String
        guard let siting = Self.siting(of: location, sampling: sampling) else { return nil }
        let fullRange = CMFormatDescriptionGetExtension(
            format,
            extensionKey: kCMFormatDescriptionExtension_FullRangeVideo
        )

        self.init(
            bitDepth: bitDepth,
            sampling: sampling,
            isFullRange: fullRange as? Bool ?? false,
            lumaRed: lumaRed,
            lumaBlue: lumaBlue,
            chromaSiting: siting
        )
    }

    // MARK: - Public
    // The R'G'B' of a buffer of this layout's pixel format, RGBA with alpha 1, rows top first, as the formulas give
    // them in double precision.
    func encodedSamples(of buffer: CVPixelBuffer) -> [Float] {
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(buffer, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(buffer, 1)
        var samples = [Float](repeating: 1, count: width * height * 4)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        nonisolated(unsafe) let luma = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!
        nonisolated(unsafe) let chroma = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)!
        let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let chromaRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let isWide = bitDepth > 8
        let code = { (base: UnsafeRawPointer, row: Int, rowBytes: Int, index: Int) -> Double in
            isWide
                ? Double(base.load(fromByteOffset: row * rowBytes + index * 2, as: UInt16.self) >> 6)
                : Double(base.load(fromByteOffset: row * rowBytes + index, as: UInt8.self))
        }
        let layout = self
        samples.withUnsafeMutableBufferPointer { output in
            nonisolated(unsafe) let output = output
            DispatchQueue.concurrentPerform(iterations: height) { y in
                let (top, bottom, down) = Self.neighbours(
                    of: y,
                    siting: layout.chromaSiting.y,
                    factor: layout.sampling.vertical,
                    count: chromaHeight
                )
                for x in 0..<width {
                    let (left, right, across) = Self.neighbours(
                        of: x,
                        siting: layout.chromaSiting.x,
                        factor: layout.sampling.horizontal,
                        count: chromaWidth
                    )
                    let chromaAt = { (component: Int) -> Double in
                        let topLeft = code(chroma, top, chromaRow, left * 2 + component)
                        let topRight = code(chroma, top, chromaRow, right * 2 + component)
                        let bottomLeft = code(chroma, bottom, chromaRow, left * 2 + component)
                        let bottomRight = code(chroma, bottom, chromaRow, right * 2 + component)
                        let upper = topLeft + (topRight - topLeft) * across
                        let lower = bottomLeft + (bottomRight - bottomLeft) * across

                        return upper + (lower - upper) * down
                    }
                    let encoded = layout.encoded(
                        luma: code(luma, y, lumaRow, x),
                        blue: chromaAt(0),
                        red: chromaAt(1)
                    )
                    let pixel = (y * width + x) * 4
                    output[pixel] = Float(encoded.red)
                    output[pixel + 1] = Float(encoded.green)
                    output[pixel + 2] = Float(encoded.blue)
                }
            }
        }

        return samples
    }

    // R'G'B' of a pixel's code values, chroma interpolated, by the range and the matrix.
    func encoded(
        luma: Double,
        blue: Double,
        red: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let y = (luma - lumaOffset) / lumaScale
        let cb = (blue - chromaOffset) / chromaScale
        let cr = (red - chromaOffset) / chromaScale
        let r = y + 2 * (1 - lumaRed) * cr
        let b = y + 2 * (1 - lumaBlue) * cb

        return (r, (y - lumaRed * r - lumaBlue * b) / lumaGreen, b)
    }

    // MARK: - Private
    // The two chroma samples nearest the centre of luma sample `index` along one axis, an edge sample standing for one
    // past the edge, and the weight of the second: its centre is at chroma coordinate (index + 0.5 − siting) / factor.
    private static func neighbours(
        of index: Int,
        siting: Double,
        factor: Int,
        count: Int
    ) -> (first: Int, second: Int, weight: Double) {
        let position = (Double(index) + 0.5 - siting) / Double(factor)
        let base = position.rounded(.down)
        let first = Int(base)

        return (min(max(first, 0), count - 1), min(max(first + 1, 0), count - 1), position - base)
    }

    // KR and KB of the H.273 matrices that have them, 2 (unspecified) standing for `srgb`'s, 1.
    private static func constants(ofMatrix matrix: Int) -> (red: Double, blue: Double)? {
        switch matrix {
        case 1, 2: (0.2126, 0.0722)
        case 4: (0.30, 0.11)
        case 5, 6: (0.299, 0.114)
        case 7: (0.212, 0.087)
        case 9: (0.2627, 0.0593)
        default: nil
        }
    }

    // The depth and chroma sampling of H.264 by its first sequence parameter set, of HEVC by its `hvcC` box's chroma
    // format and depths, and of ProRes 422, which is 10-bit 4:2:2.
    private static func samples(of format: CMFormatDescription) -> (bitDepth: Int, sampling: ChromaSampling)? {
        switch CMFormatDescriptionGetMediaSubType(format) {
        case kCMVideoCodecType_H264:
            return sequenceSamples(of: format)

        case kCMVideoCodecType_HEVC, FourCharCode(0x6865_7631):
            // `hev1` and `hvc1`: the chroma format at byte 16 and the depths less 8 at bytes 17 and 18.
            let atoms = CMFormatDescriptionGetExtension(
                format,
                extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms
            ) as? [String: Any]
            guard let hvcC = (atoms?["hvcC"] as? Data).map([UInt8].init), hvcC.count > 18 else { return nil }
            let lumaDepth = Int(hvcC[17] & 0x07) + 8
            let chromaDepth = Int(hvcC[18] & 0x07) + 8
            guard lumaDepth == chromaDepth, [8, 10].contains(lumaDepth) else { return nil }

            return sampling(ofChromaFormat: Int(hvcC[16] & 0x03)).map { (lumaDepth, $0) }

        case kCMVideoCodecType_AppleProRes422, kCMVideoCodecType_AppleProRes422HQ, kCMVideoCodecType_AppleProRes422LT,
            kCMVideoCodecType_AppleProRes422Proxy:
            return (10, .fourTwoTwo)

        default:
            return nil
        }
    }

    // The depth and chroma sampling an H.264 stream's first sequence parameter set gives: 8-bit 4:2:0 for a profile
    // with no other, and otherwise its `chroma_format_idc`, `separate_colour_plane_flag` where that is 3, and its two
    // depths less 8, after its header byte, profile, constraints, level and `seq_parameter_set_id`, each but the flag
    // an Exp-Golomb code, read once the stream's emulation prevention bytes are taken out.
    private static func sequenceSamples(of format: CMFormatDescription) -> (bitDepth: Int, sampling: ChromaSampling)? {
        let profilesWithChromaFormat: Set<UInt8> = [44, 83, 86, 100, 110, 118, 122, 128, 134, 135, 138, 139, 244]
        var pointer: UnsafePointer<UInt8>?
        var size = 0
        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            parameterSetIndex: 0,
            parameterSetPointerOut: &pointer,
            parameterSetSizeOut: &size,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )
        guard status == noErr, let pointer, size > 4 else { return nil }

        var payload: [UInt8] = []
        var zeros = 0
        for byte in UnsafeBufferPointer(start: pointer, count: size).dropFirst() {
            if zeros >= 2, byte == 3 {
                zeros = 0
                continue
            }
            zeros = byte == 0 ? zeros + 1 : 0
            payload.append(byte)
        }
        guard payload.count > 3 else { return nil }
        guard profilesWithChromaFormat.contains(payload[0]) else { return (8, .fourTwoZero) }

        var bit = 24
        let next = { () -> Int? in
            guard bit < payload.count * 8 else { return nil }
            defer { bit += 1 }

            return Int(payload[bit / 8] >> (7 - UInt8(bit % 8)) & 1)
        }
        let golomb = { () -> Int? in
            var leadingZeros = 0
            while true {
                guard let value = next() else { return nil }
                if value == 1 { break }
                leadingZeros += 1
                guard leadingZeros < 32 else { return nil }
            }
            var value = 0
            for _ in 0..<leadingZeros {
                guard let bit = next() else { return nil }
                value = value << 1 | bit
            }

            return (1 << leadingZeros) - 1 + value
        }
        guard golomb() != nil, let chromaFormat = golomb() else { return nil }
        if chromaFormat == 3, next() == nil { return nil }
        guard let lumaDepth = golomb().map({ $0 + 8 }), let chromaDepth = golomb().map({ $0 + 8 }) else { return nil }
        guard lumaDepth == chromaDepth, [8, 10].contains(lumaDepth) else { return nil }

        return sampling(ofChromaFormat: chromaFormat).map { (lumaDepth, $0) }
    }

    // The sampling of H.264's and HEVC's `chroma_format_idc`, nil for 0, monochrome.
    private static func sampling(ofChromaFormat format: Int) -> ChromaSampling? {
        switch format {
        case 1: .fourTwoZero
        case 2: .fourTwoTwo
        case 3: .fourFourFour
        default: nil
        }
    }

    // Where a chroma sample stands by the chroma location tag, H.273's default, left, where there is none. Nil for DV
    // 4:2:0, whose Cb and Cr stand apart.
    private static func siting(
        of location: String?,
        sampling: ChromaSampling
    ) -> SIMD2<Double>? {
        let names = [
            kCMFormatDescriptionChromaLocation_Left as String: (0.5, 1.0),
            kCMFormatDescriptionChromaLocation_Center as String: (1.0, 1.0),
            kCMFormatDescriptionChromaLocation_TopLeft as String: (0.5, 0.5),
            kCMFormatDescriptionChromaLocation_Top as String: (1.0, 0.5),
            kCMFormatDescriptionChromaLocation_BottomLeft as String: (0.5, 1.5),
            kCMFormatDescriptionChromaLocation_Bottom as String: (1.0, 1.5)
        ]
        guard let (x, y) = location.map({ names[$0] }) ?? (0.5, 1.0) else { return nil }

        return SIMD2(sampling.horizontal == 1 ? 0.5 : x, sampling.vertical == 1 ? 0.5 : y)
    }
}
