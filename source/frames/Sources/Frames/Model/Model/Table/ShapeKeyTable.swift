//
//  ShapeKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The appearance keys a shape clip and a shape style share, `shadow` also a media clip's and a storyline clip's, and the
// shape style itself, read from their look structures. A gradient's points and stops are required of the merged value,
// so a clip may change one leaf of its style's gradient.
enum ShapeKeyTable {
    static let gradient = ValueType(structure: .forms(LookStructureTable.gradientForms), kind: "gradient")
    // A fill's object form is its gradient.
    static let fill = ValueType(written: LookStructureTable.fill, kind: "gradient")
    static let stroke = ValueType(written: LookStructureTable.stroke, kind: "stroke")
    static let shadow = ValueType(written: LookStructureTable.shadow, kind: "shadow")
    static let style = ObjectTable(
        kind: "shape style",
        rules: LookStructureTable.shapeStyle.keys.map { key in
            KeyRule(key.name, key.name == "fill" ? fill : ValueType(written: key.structure, kind: key.name))
        }
    )
}
