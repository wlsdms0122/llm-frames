//
//  Loudness+Text.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The text `loudness` prints for people: one measure a line with its unit, `none` where the meter gives none. It is
// not part of the contract.
extension Loudness {
    // MARK: - Property
    package var text: String {
        [
            "integrated \(written(integrated, unit: "LUFS"))",
            "range \(written(range, unit: "LU"))",
            "momentary max \(written(momentaryMax, unit: "LUFS"))",
            "short-term max \(written(shortTermMax, unit: "LUFS"))",
            "true peak \(written(truePeak, unit: "dBTP"))",
            "sample peak \(written(samplePeak, unit: "dBFS"))"
        ].joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func written(
        _ measure: Double?,
        unit: String
    ) -> String {
        measure.map { "\(JSONValue.number($0).written) \(unit)" } ?? "none"
    }
}
