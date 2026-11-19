//
//  MaskKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The keys of a mask for each shape it can be, read from the mask's look structure: a rect or an ellipse takes a box,
// by `area` or by `width`, `height` and `position`, and only a rect a `radius`, and a path takes `points`. A key its
// shape does not take stops as an unknown key. A mask's geometry is written as a clip's is, an area or a point found by
// text included, so `area`, `position` and `points` take the clip's geometry types, where the structure holds the
// numbers they are found as.
enum MaskKeyTable {
    static let box = ["width", "height", "position"]

    // A shape's groups are those of the structure among the keys it takes: `area` with each key of the box.
    static func table(for shape: ShapeKind) -> ObjectTable {
        let geometry = switch shape {
        case .rect:
            ["area"] + box + ["radius"]

        case .ellipse:
            ["area"] + box

        case .path:
            ["points"]
        }
        let keys = ["shape"] + geometry + ["feather", "invert", "mode"]

        return ObjectTable(
            kind: "\(shape.rawValue) mask",
            rules: mask.rules.filter { keys.contains($0.name) },
            groups: mask.groups.filter { $0.keys.allSatisfy(keys.contains) }
        )
    }

    // A keyframe's mask: every key a mask of any shape takes, the keys its static mask's shape takes and their groups
    // being checked with the static mask.
    static let keyframe = ObjectTable(kind: "mask", rules: mask.rules)

    private static let mask: ObjectTable = {
        guard case let .list(.object(structure)) = LookStructureTable.mask else {
            return ObjectTable(kind: "mask", rules: [])
        }

        let table = ObjectTable(structure: structure, kind: "mask")
        let written: [String: ValueType] = ["area": .area, "position": AreaKeyTable.point, "points": .points]
        return ObjectTable(
            kind: table.kind,
            rules: table.rules.map { rule in written[rule.name].map { KeyRule(rule.name, $0) } ?? rule },
            groups: table.groups
        )
    }()
}
