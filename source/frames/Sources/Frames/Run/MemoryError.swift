//
//  MemoryError.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

import Foundation

package enum MemoryError: Error, Equatable, CustomStringConvertible, Sendable {
    // `floors` holds every holder's floor in `MemoryHolder`'s order.
    case underFloor(limit: MemorySize, floors: [MemoryHolderUsage])

    // MARK: - Property
    package var description: String {
        switch self {
        case let .underFloor(limit, floors):
            let floor = floors.reduce(0) { $0 + $1.floor }
            let holders = floors.map { "\($0.holder.name) \(Self.written($0.floor))" }.joined(separator: ", ")

            return "memory limit \(limit.written) is under the \(Self.written(floor)) this run needs: \(holders)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // `bytes` in GB of 2^30 bytes to two places from 1 GB, and in MB of 2^20 bytes to one place below, with no
    // trailing zeros: 1.31 GB, 0.5 MB, 0 MB.
    private static func written(_ bytes: Int) -> String {
        let (unit, name, places) = bytes >= MemorySize.gigabyte
            ? (MemorySize.gigabyte, "GB", 2)
            : (MemorySize.megabyte, "MB", 1)
        let written = String(format: "%.\(places)f", Double(bytes) / Double(unit))
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)

        return "\(written) \(name)"
    }
}
