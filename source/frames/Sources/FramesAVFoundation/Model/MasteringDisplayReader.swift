//
//  MasteringDisplayReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// Reads the maximum luminance of a still's mastering display in cd/m², from the SMPTE ST 2086 colour volume it
// carries: the `mDCv` chunk of a PNG, or the first `mdcv` item property of a HEIF or AVIF file (ISO/IEC 23008-12). Both
// hold the luminance in units of 0.0001 cd/m², a 32-bit number at byte 16. Numbers are big-endian.
struct MasteringDisplayReader {
    // MARK: - Property
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    private let bytes: Data

    // MARK: - Initializer
    init(data: Data) {
        self.bytes = data
    }

    // MARK: - Public
    // Nil for a file that carries no colour volume, or one whose maximum luminance is 0.
    func peak() -> Double? {
        let volume = bytes.starts(with: Self.pngSignature) ? pngVolume() : itemPropertyVolume()
        guard let volume, let luminance = uint32(at: volume + 16), luminance > 0 else { return nil }

        return Double(luminance) / 10000
    }

    // MARK: - Private
    // The offset of the `mDCv` chunk's data. The chunk comes before the image data.
    private func pngVolume() -> Int? {
        var offset = bytes.startIndex + Self.pngSignature.count
        while let length = uint32(at: offset), let type = signature(at: offset + 4) {
            switch type {
            case "mDCv":
                return length >= 24 ? offset + 8 : nil

            case "IDAT", "IEND":
                return nil

            default:
                offset += 12 + length
            }
        }

        return nil
    }

    // The offset of the first `mdcv` box's data, in the item property container `meta`, `iprp`, `ipco`.
    private func itemPropertyVolume() -> Int? {
        guard
            let meta = box("meta", in: bytes.startIndex..<bytes.endIndex),
            let properties = box("iprp", in: meta.lowerBound + 4..<meta.upperBound),
            let container = box("ipco", in: properties),
            let volume = box("mdcv", in: container),
            volume.count >= 24
        else {
            return nil
        }

        return volume.lowerBound
    }

    // The data of the first box of `type` among the boxes over `range`.
    private func box(
        _ type: String,
        in range: Range<Int>
    ) -> Range<Int>? {
        var offset = range.lowerBound
        while offset + 8 <= range.upperBound, let size = uint32(at: offset), let name = signature(at: offset + 4) {
            var header = 8
            var end = size == 0 ? range.upperBound : offset + size
            if size == 1 {
                guard let high = uint32(at: offset + 8), let low = uint32(at: offset + 12) else { return nil }
                header = 16
                end = offset + (high << 32 | low)
            }
            guard end >= offset + header, end <= range.upperBound else { return nil }
            if name == type { return offset + header..<end }

            offset = end
        }

        return nil
    }

    private func signature(at offset: Int) -> String? {
        guard offset >= bytes.startIndex, offset + 4 <= bytes.endIndex else { return nil }

        return String(bytes: bytes[offset..<offset + 4], encoding: .ascii)
    }

    private func uint32(at offset: Int) -> Int? {
        guard offset >= bytes.startIndex, offset + 4 <= bytes.endIndex else { return nil }

        return (0..<4).reduce(0) { value, index in value << 8 | Int(bytes[offset + index]) }
    }
}
