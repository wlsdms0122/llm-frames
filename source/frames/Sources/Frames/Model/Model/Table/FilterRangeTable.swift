//
//  FilterRangeTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum FilterRangeTable {
    static func ranges(of operation: String) -> [(parameter: String, range: ParameterRange)] {
        switch operation {
        case "sepia", "lut":
            [("amount", .unit)]

        case "levels":
            [("input", .levels), ("output", .levels)]

        case "blur", "sharpen", "bloom":
            [("radius", .positive)]

        case "pixelate":
            [("size", .positive)]

        case "grain":
            [("amount", .unit), ("size", .positive)]

        case "vignette":
            [("radius", .unit)]

        default:
            []
        }
    }
}
