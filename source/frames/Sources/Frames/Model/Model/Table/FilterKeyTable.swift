//
//  FilterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The keys of a filter op, read from its look structure. Only `op` is required here: the parameters an op requires are
// required of the merged value, since keyframes may give them in place of the clip. Their ranges are checked by
// `PresetReader.checkRanges`, which lets a length a sampled argument fills be 0, so every number here is any number.
enum FilterKeyTable {
    static let operations = [
        "exposure", "contrast", "saturation", "temperature", "hue", "sepia", "levels", "lut",
        "blur", "sharpen", "bloom", "vignette", "pixelate", "grain"
    ]

    static func table(for operation: String) -> ObjectTable {
        let parameters = if case let .object(object) = LookStructureTable.filterOperation(operation) {
            ObjectTable(structure: object, kind: operation, checksDomains: false).rules
        } else {
            [KeyRule]()
        }

        return ObjectTable(kind: operation, rules: [KeyRule("op", .literal(operations), isRequired: true)] + parameters)
    }
}
