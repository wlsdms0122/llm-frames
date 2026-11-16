//
//  FilterKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum FilterKeyTable {
    static let operations = [
        "exposure", "contrast", "saturation", "temperature", "hue", "sepia", "levels", "lut",
        "blur", "sharpen", "bloom", "vignette", "pixelate", "grain"
    ]

    static func table(for operation: String) -> ObjectTable {
        ObjectTable(
            kind: operation,
            rules: [KeyRule("op", .literal(operations), isRequired: true)] + parameters(of: operation)
        )
    }

    private static func parameters(of operation: String) -> [KeyRule] {
        switch operation {
        case "exposure":
            [required("ev")]

        case "contrast", "saturation", "sepia":
            [required("amount")]

        case "temperature":
            [required("kelvin")]

        case "hue":
            [required("degrees")]

        case "levels":
            [
                KeyRule("input", .numbers(2), isRequired: true),
                KeyRule("output", .numbers(2), isRequired: true)
            ]

        case "lut":
            [KeyRule("file", .name, isRequired: true), required("amount")]

        case "blur":
            [required("radius")]

        case "sharpen", "vignette":
            [required("amount"), required("radius")]

        case "bloom":
            [required("amount"), required("radius"), KeyRule("color", .color)]

        case "pixelate":
            [required("size")]

        default:
            [required("amount"), required("size")]
        }
    }

    private static func required(_ name: String) -> KeyRule {
        KeyRule(name, .number, isRequired: true)
    }
}
