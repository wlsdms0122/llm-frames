//
//  StrokeHead+Written.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A head as a preset and a resolved document write it: `points`, each vertex a point `[x, y]` or `{vertex, inTangent,
// outTangent}` whose missing tangents are `[0, 0]`, beside `length` and `inset`. Read from values a key check has
// passed, and written with every vertex whole.
extension StrokeHead {
    // MARK: - Property
    // The members a head writes, in order.
    static let keys = ["points", "length", "inset"]

    // Its outline with every vertex written whole.
    var points: JSONValue {
        .array(outline.map { vertex in
            .object(JSONObject(members: [
                JSONMember(key: "vertex", value: Self.written(vertex.vertex)),
                JSONMember(key: "inTangent", value: Self.written(vertex.inTangent)),
                JSONMember(key: "outTangent", value: Self.written(vertex.outTangent))
            ]))
        })
    }

    var members: [JSONMember] {
        [
            JSONMember(key: "points", value: points),
            JSONMember(key: "length", value: .number(length)),
            JSONMember(key: "inset", value: .number(inset))
        ]
    }

    // MARK: - Initializer
    // A head written as one object, as a head preset's file and a resolved stroke's end hold it, nil where a value is
    // not of its form.
    package init?(written value: JSONValue) {
        guard let object = value.objectValue else { return nil }

        self.init(points: object["points"], length: object["length"], inset: object["inset"])
    }

    // Nil where a value is not of its form.
    init?(
        points: JSONValue?,
        length: JSONValue?,
        inset: JSONValue?
    ) {
        guard
            let elements = points?.arrayValue,
            let length = length?.numberValue,
            let inset = inset?.numberValue
        else { return nil }

        var outline: [PathVertex<Point, Point>] = []
        for element in elements {
            guard let vertex = Self.vertex(element) else { return nil }

            outline.append(vertex)
        }
        self.init(outline: outline, length: length, inset: inset)
    }

    // MARK: - Public
    // MARK: - Private
    private static func vertex(_ value: JSONValue) -> PathVertex<Point, Point>? {
        guard let object = value.objectValue else {
            return point(value).map { PathVertex(vertex: $0, inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 0)) }
        }
        guard let vertex = object["vertex"].flatMap(point) else { return nil }

        let tangent = { (key: String) -> Point? in object[key].map(point) ?? Point(x: 0, y: 0) }
        guard let inTangent = tangent("inTangent"), let outTangent = tangent("outTangent") else { return nil }

        return PathVertex(vertex: vertex, inTangent: inTangent, outTangent: outTangent)
    }

    private static func point(_ value: JSONValue) -> Point? {
        guard
            let numbers = value.arrayValue?.compactMap(\.numberValue),
            numbers.count == 2,
            value.arrayValue?.count == 2
        else { return nil }

        return Point(x: numbers[0], y: numbers[1])
    }

    private static func written(_ point: Point) -> JSONValue {
        .array([.number(point.x), .number(point.y)])
    }
}
