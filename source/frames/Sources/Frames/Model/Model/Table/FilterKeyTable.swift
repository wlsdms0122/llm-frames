//
//  FilterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The keys of a filter op, read from its look structure. Only `kind` is required here: the parameters an op requires are
// required of the merged value, since keyframes may give them in place of the clip. Their ranges are checked by
// `PresetReader.checkRanges`, which lets a length a sampled argument fills be 0, so every number here is any number.
enum FilterKeyTable {
    static let operations = [
        "exposure", "contrast", "saturation", "temperature", "hue", "sepia", "levels", "lut",
        "blur", "sharpen", "bloom", "vignette", "displace", "pixelate", "grain"
    ]

    // An op of a preset's `ops`.
    static let operationKinds = KindTable(kind: "filter operation", tables: tables(mixed: false))
    // An op written in place in a filter choice, which takes `mix` beside its parameters.
    static let mixedOperationTables = tables(mixed: true)

    static func table(for operation: String) -> ObjectTable {
        let parameters = if case let .object(object) = LookStructureTable.filterOperation(operation) {
            ObjectTable(structure: object, kind: operation, checksDomains: false).rules
        } else {
            [KeyRule]()
        }

        return ObjectTable(kind: operation, rules: [KeyRule("kind", .literal([operation]), isRequired: true)] + parameters)
    }

    private static func tables(mixed: Bool) -> [String: ObjectTable] {
        Dictionary(uniqueKeysWithValues: operations.map { operation in
            let table = table(for: operation)
            let mix = mixed ? [KeyRule("mix", .number(.range(0...1)))] : []
            return (operation, ObjectTable(kind: table.kind, rules: table.rules + mix))
        })
    }
}
