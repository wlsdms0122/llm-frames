//
//  ICCProfileWriter.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// ICC v4 monochrome display profiles built byte by byte (ICC.1): a header, `desc`, `cprt`, a D50 `wtpt` and one `kTRC`
// tone curve. Numbers are big-endian.
struct ICCProfileWriter {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A `para` curve of `functionType` and its parameters, each stored in s15Fixed16.
    static func parametric(
        functionType: Int,
        parameters: [Double]
    ) -> [UInt8] {
        Array("para".utf8) + [0, 0, 0, 0] + uint16(functionType) + [0, 0] + parameters.flatMap(fixed)
    }

    // A `curv` of entries from 0 to 1, each stored as a 16-bit fraction.
    static func table(_ entries: [Double]) -> [UInt8] {
        Array("curv".utf8) + [0, 0, 0, 0] + uint32(entries.count)
            + entries.flatMap { uint16(Int(($0 * 65535).rounded())) } + (entries.count % 2 == 1 ? [0, 0] : [])
    }

    static func grayProfile(curve: [UInt8]) -> Data {
        let tags: [(String, [UInt8])] = [
            ("desc", text("Test gray")),
            ("cprt", text("No copyright")),
            ("wtpt", Array("XYZ ".utf8) + [0, 0, 0, 0] + fixed(0.9642) + fixed(1) + fixed(0.8249)),
            ("kTRC", curve)
        ]
        var header = [UInt8](repeating: 0, count: 128)
        let put = { (offset: Int, bytes: [UInt8]) in header.replaceSubrange(offset..<offset + bytes.count, with: bytes) }
        put(8, [0x04, 0x30, 0, 0])
        put(12, Array("mntrGRAYXYZ ".utf8))
        put(36, Array("acsp".utf8))
        put(68, fixed(0.9642) + fixed(1) + fixed(0.8249))

        var table = uint32(tags.count)
        var body: [UInt8] = []
        let start = 128 + 4 + tags.count * 12
        for (signature, element) in tags {
            table += Array(signature.utf8) + uint32(start + body.count) + uint32(element.count)
            body += element
            while body.count % 4 != 0 { body.append(0) }
        }
        var profile = header + table + body
        profile.replaceSubrange(0..<4, with: uint32(profile.count))

        return Data(profile)
    }

    // MARK: - Private
    private static func text(_ string: String) -> [UInt8] {
        let units = Array(string.utf16)

        return Array("mluc".utf8) + [0, 0, 0, 0] + uint32(1) + uint32(12) + Array("enUS".utf8)
            + uint32(units.count * 2) + uint32(28) + units.flatMap { uint16(Int($0)) }
    }

    private static func fixed(_ value: Double) -> [UInt8] {
        uint32(Int(UInt32(bitPattern: Int32((value * 65536).rounded()))))
    }

    private static func uint16(_ value: Int) -> [UInt8] {
        [UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func uint32(_ value: Int) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }
}
