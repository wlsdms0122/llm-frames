//
//  VariationSequenceTable.swift
//  FramesCoreText
//
//  Created by JSilver on 11/21/26.
//

import CoreText
import Foundation

// The variation sequences a face maps in the format 14 subtable of its `cmap` table: for each variation selector, the
// base characters it may follow, set in the base's own glyph (default UVS) or in a glyph of its own (non-default
// UVS).
struct VariationSequenceTable {
    // MARK: - Property
    // Bytes of a selector record, a default UVS range and a non-default UVS mapping.
    private static let selectorRecordSize = 11
    private static let rangeSize = 4
    private static let mappingSize = 5

    private let bases: [UInt32: [ClosedRange<UInt32>]]

    // MARK: - Initializer
    init(font: CTFont) {
        let data = CTFontCopyTable(font, CTFontTableTag(kCTFontTableCmap), []) as Data?
        self.bases = data.map { Self.bases(in: [UInt8]($0)) } ?? [:]
    }

    // MARK: - Public
    func contains(
        base: Unicode.Scalar,
        selector: Unicode.Scalar
    ) -> Bool {
        bases[selector.value]?.contains { $0.contains(base.value) } ?? false
    }

    // MARK: - Private
    // The subtable is the one of platform 0 (Unicode), encoding 5 (variation sequences).
    private static func bases(in table: [UInt8]) -> [UInt32: [ClosedRange<UInt32>]] {
        guard let count = uint(in: table, at: 2, size: 2) else { return [:] }
        let record = (0..<Int(count)).map { 4 + $0 * 8 }.first { offset in
            uint(in: table, at: offset, size: 2) == 0 && uint(in: table, at: offset + 2, size: 2) == 5
        }
        guard let record,
              let start = uint(in: table, at: record + 4, size: 4).map(Int.init),
              uint(in: table, at: start, size: 2) == 14,
              let selectors = uint(in: table, at: start + 6, size: 4)
        else { return [:] }

        var bases: [UInt32: [ClosedRange<UInt32>]] = [:]
        for index in 0..<Int(selectors) {
            let offset = start + 10 + index * selectorRecordSize
            guard let selector = uint(in: table, at: offset, size: 3),
                  let defaults = uint(in: table, at: offset + 3, size: 4).map(Int.init),
                  let others = uint(in: table, at: offset + 7, size: 4).map(Int.init)
            else { break }

            var ranges: [ClosedRange<UInt32>] = []
            if defaults != 0, let count = uint(in: table, at: start + defaults, size: 4) {
                for range in 0..<Int(count) {
                    let at = start + defaults + 4 + range * rangeSize
                    guard let first = uint(in: table, at: at, size: 3),
                          let additional = uint(in: table, at: at + 3, size: 1)
                    else { break }
                    ranges.append(first...first + additional)
                }
            }
            if others != 0, let count = uint(in: table, at: start + others, size: 4) {
                for mapping in 0..<Int(count) {
                    guard let value = uint(in: table, at: start + others + 4 + mapping * mappingSize, size: 3) else {
                        break
                    }
                    ranges.append(value...value)
                }
            }
            bases[selector] = ranges
        }

        return bases
    }

    // The big-endian unsigned integer of `size` bytes at `offset`, or nil past the table's end.
    private static func uint(
        in table: [UInt8],
        at offset: Int,
        size: Int
    ) -> UInt32? {
        guard offset >= 0, offset + size <= table.count else { return nil }

        return table[offset..<offset + size].reduce(0) { $0 << 8 | UInt32($1) }
    }
}
