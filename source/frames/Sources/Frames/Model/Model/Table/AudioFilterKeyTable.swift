//
//  AudioFilterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The keys of an audio op and of an `eq` band, by the op or the band's `type`. Ranges are the look structure's
// (`LookStructureTable.audioOperation`), which resolve checks, and so are a band's required `frequency` and `gain`,
// which keyframes may give in place of the clip.
enum AudioFilterKeyTable {
    static let kind = "audio filter choice"
    static let operations = ["eq", "compressor", "gate"]
    static let bandTypes = MixBandType.allCases.map(\.rawValue)

    static func table(for operation: String) -> ObjectTable {
        ObjectTable(
            kind: operation,
            rules: [KeyRule("op", .literal(operations), isRequired: true)] + parameters(of: operation)
        )
    }

    // A pass filter has no gain, so a `gain` on one stops as a key its type does not take.
    static func band(of type: String) -> ObjectTable {
        let gain = MixBandType(rawValue: type)?.takesGain == true ? [KeyRule("gain", .number)] : []

        return ObjectTable(
            kind: "band",
            rules: [
                KeyRule("type", .literal(bandTypes), isRequired: true),
                KeyRule("frequency", .number)
            ] + gain + [KeyRule("q", .number)]
        )
    }

    private static func parameters(of operation: String) -> [KeyRule] {
        switch operation {
        case "eq":
            [KeyRule("bands", .list(.anyObject), isRequired: true)]

        case "compressor":
            [
                KeyRule("threshold", .number, isRequired: true),
                KeyRule("ratio", .number, isRequired: true),
                KeyRule("knee", .number),
                KeyRule("attack", .number),
                KeyRule("release", .number),
                KeyRule("makeup", .number)
            ]

        default:
            [
                KeyRule("threshold", .number, isRequired: true),
                KeyRule("range", .number),
                KeyRule("attack", .number),
                KeyRule("hold", .number),
                KeyRule("release", .number)
            ]
        }
    }
}
