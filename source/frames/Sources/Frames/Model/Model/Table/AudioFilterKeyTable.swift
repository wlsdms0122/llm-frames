//
//  AudioFilterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The keys of an audio op and of an `eq` band, by the op's or the band's `kind`, read from their look structures. Only
// `kind` is required here: the keys an op or a band requires are required of the merged value, since keyframes
// may give them in place of the clip. Their domains are checked by `ValueStructure.checkDomains(of:place:sampled:)`,
// which lets a leaf a sampled argument fills take any value its samples take, so every number here is any number.
enum AudioFilterKeyTable {
    static let kind = "audio filter choice"
    static let operations = ["eq", "compressor", "gate", "limiter", "convolve"]
    static let bandKinds = MixBandType.allCases.map(\.rawValue)

    static func table(for operation: String) -> ObjectTable {
        ObjectTable(
            kind: operation,
            rules: [KeyRule("kind", .literal(operations), isRequired: true)]
                + rules(of: LookStructureTable.audioOperation(operation), kind: operation)
        )
    }

    // A pass filter has no gain, so a `gain` on one stops as a key its kind does not take.
    static func band(of kind: String) -> ObjectTable {
        ObjectTable(
            kind: "band",
            rules: [KeyRule("kind", .literal(bandKinds), isRequired: true)]
                + rules(of: LookStructureTable.band.structure(ofForm: "kind:" + kind), kind: "band")
        )
    }

    private static func rules(
        of structure: ValueStructure?,
        kind: String
    ) -> [KeyRule] {
        guard case let .object(object)? = structure else { return [] }

        return ObjectTable(structure: object, kind: kind, checksDomains: false).rules
    }
}
