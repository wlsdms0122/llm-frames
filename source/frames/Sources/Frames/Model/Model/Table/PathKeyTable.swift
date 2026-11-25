//
//  PathKeyTable.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A vertex of a path's `points` (FRAMES-11 Paths): `[x, y]`, or the vertex object `{vertex, inTangent, outTangent}`,
// the one object form there, whose `vertex` is a point as `position` takes it and whose tangents are offsets of two
// numbers that take no form of an area. `[x, y]` is a vertex that names its point alone, so its one leaf is `vertex`,
// and a vertex object's leaves are the keys it writes.
enum PathKeyTable {
    // MARK: - Property
    static let leafKeys = ["vertex", "inTangent", "outTangent"]
    static let tangent = ValueType.numbers(2, .any)

    // MARK: - Initializer
    // MARK: - Public
    // A vertex object outside a keyframe writes its `vertex`, and one in a keyframe may leave it out for the value
    // below.
    static func vertex(isKeyframed: Bool) -> ValueType {
        .oneOf([
            .numbers(2, .any),
            .object(ObjectTable(
                kind: "path vertex",
                rules: [
                    KeyRule("vertex", AreaKeyTable.point, isRequired: !isKeyframed),
                    KeyRule("inTangent", tangent),
                    KeyRule("outTangent", tangent)
                ]
            ))
        ])
    }

    // Whether a vertex is written as a vertex object and not as `[x, y]`.
    static func isVertexObject(_ vertex: JSONValue) -> Bool {
        vertex.objectValue != nil
    }

    // The point a vertex writes, and where it is written from where the vertex is: the vertex itself where it is
    // `[x, y]`, and its `vertex` where it is a vertex object.
    static func point(of vertex: JSONValue) -> JSONValue? {
        isVertexObject(vertex) ? vertex.objectValue?["vertex"] : vertex
    }

    static func place(
        ofPointOf vertex: JSONValue,
        at place: Place
    ) -> Place {
        isVertexObject(vertex) ? place.appending(key: "vertex") : place
    }

    // The leaves a vertex writes, by their keys.
    static func leaves(of vertex: JSONValue) -> [String] {
        guard isVertexObject(vertex), let object = vertex.objectValue else { return ["vertex"] }

        return object.keys.filter(leafKeys.contains)
    }

    // MARK: - Private
}
