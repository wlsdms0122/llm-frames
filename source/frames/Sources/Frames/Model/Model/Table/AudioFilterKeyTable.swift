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

    // An op of a preset's `ops`.
    static let operationKinds = KindTable(kind: "audio operation", tables: tables(mixed: false))
    // An op written in place in an audio filter choice, which takes `mix` beside its parameters.
    static let mixedOperationTables = tables(mixed: true)

    // An `eq`'s bands are each of the kind their `kind` names.
    static func table(for operation: String) -> ObjectTable {
        ObjectTable(
            kind: operation,
            rules: [KeyRule("kind", .literal([operation]), isRequired: true)]
                + rules(of: LookStructureTable.audioOperation(operation), kind: operation).map { rule in
                    rule.name == "bands" ? KeyRule("bands", .list(.kinds(bands))) : rule
                }
        )
    }

    // A pass filter has no gain, so a `gain` on one stops as a key its kind does not take.
    static let bands = KindTable(
        kind: "band",
        tables: Dictionary(uniqueKeysWithValues: bandKinds.map { kind in
            (kind, ObjectTable(
                kind: "band",
                rules: [KeyRule("kind", .literal([kind]), isRequired: true)]
                    + rules(of: LookStructureTable.band.structure(ofForm: "kind:" + kind), kind: "band")
            ))
        })
    )

    private static func tables(mixed: Bool) -> [String: ObjectTable] {
        Dictionary(uniqueKeysWithValues: operations.map { operation in
            let table = table(for: operation)
            let mix = mixed ? [KeyRule("mix", .number(.range(0...1)))] : []
            return (operation, ObjectTable(kind: table.kind, rules: table.rules + mix))
        })
    }

    private static func rules(
        of structure: ValueStructure?,
        kind: String
    ) -> [KeyRule] {
        guard case let .object(object)? = structure else { return [] }

        return ObjectTable(structure: object, kind: kind, checksDomains: false).rules
    }
}
