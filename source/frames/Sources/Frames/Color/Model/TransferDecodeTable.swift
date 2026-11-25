//
//  TransferDecodeTable.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// An SDR transfer's decode at every half-float value, indexed by the value's bit pattern, for the samples of a picture
// rendered at half floats. Each entry is the transfer's own decode of that value, so a value that is a half float
// decodes to the same bits by lookup, and any other value, NaN among them, is decoded by the transfer. The table of a
// transfer is built once and shared.
package struct TransferDecodeTable: Equatable, Sendable {
    // MARK: - Property
    private static let lock = NSLock()
    nonisolated(unsafe) private static var tables: [TransferFunction: TransferDecodeTable] = [:]

    package let transfer: TransferFunction
    // The decoded value of each half float, by its bit pattern.
    package let values: [Double]

    // MARK: - Initializer
    // The shared table of `transfer`.
    package init(_ transfer: TransferFunction) {
        self = Self.lock.withLock {
            if let table = Self.tables[transfer] { return table }

            let table = TransferDecodeTable(building: transfer)
            Self.tables[transfer] = table

            return table
        }
    }

    private init(building transfer: TransferFunction) {
        self.transfer = transfer
        self.values = (0...UInt16.max).map { transfer.decode(Double(Float16(bitPattern: $0))) }
    }

    // MARK: - Public
    package func decode(_ encoded: Double) -> Double {
        let half = Float16(encoded)
        guard Double(half) == encoded else { return transfer.decode(encoded) }

        return values[Int(half.bitPattern)]
    }

    package func decode(_ encoded: RGB) -> RGB {
        encoded.map(decode)
    }

    // MARK: - Private
}
