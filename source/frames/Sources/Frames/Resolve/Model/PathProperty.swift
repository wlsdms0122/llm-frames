//
//  PathProperty.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A path shape's `points` as written (FRAMES-11 Paths): its static vertices and each keyframe's that writes `points`,
// every vertex as the document writes it, a point or a vertex object, which the key tables have checked. Keyframes
// are on the clip's clock.
struct PathProperty: Equatable, Sendable {
    // MARK: - Property
    let written: [JSONValue]?
    let keyframes: [PropertyKeyframe<[JSONValue]>]

    // Each vertex's point and tangents as leaves timed on their own (FRAMES-4): a leaf takes the keyframes that write
    // it and the static value where none does, since the key checks stop a leaf written in both. A tangent nothing
    // writes is `[0, 0]`, and a point nothing writes has no keyframes, which planning the shape's geometry stops. The
    // path has as many vertices as its static value, or its first keyframe where it has none.
    var vertices: [PathVertex<PropertyValue<PositionForm>, PropertyValue<Point>>] {
        let count = written?.count ?? keyframes.first?.value.count ?? 0

        return (0..<count).map { index in
            PathVertex(
                vertex: leaf(of: index, read: Self.point(of:)) ?? .keyframes([]),
                inTangent: leaf(of: index) { Self.tangent($0, key: "inTangent") } ?? .value(Self.zero),
                outTangent: leaf(of: index) { Self.tangent($0, key: "outTangent") } ?? .value(Self.zero)
            )
        }
    }

    private static let zero = Point(x: 0, y: 0)

    // MARK: - Initializer
    init(
        written: [JSONValue]?,
        keyframes: [PropertyKeyframe<[JSONValue]>]
    ) {
        self.written = written
        self.keyframes = keyframes
    }

    // MARK: - Public
    // Where a vertex's point is written, statically or in the keyframe at `keyframe`: `points[i]` for a point and
    // `points[i].vertex` for a vertex object, under the keyframe for a keyframe's.
    func place(
        ofPoint index: Int,
        keyframe: Int?,
        in clip: Place
    ) -> Place {
        let list = keyframe.map { keyframe in
            clip.appending(key: "keyframes").appending(index: keyframe).appending(key: "points")
        } ?? clip.appending(key: "points")
        let vertices = keyframe.map { keyframe in keyframes.first { $0.index == keyframe }?.value } ?? written
        let place = list.appending(index: index)
        guard let vertex = vertices.flatMap({ $0.indices.contains(index) ? $0[index] : nil }) else { return place }

        return PathKeyTable.place(ofPointOf: vertex, at: place)
    }

    // Every vertex's point written, statically and in keyframes, with where it is written.
    func points(in clip: Place) -> [(form: PositionForm, place: Place)] {
        let lists = (written.map { [(nil as Int?, $0)] } ?? []) + keyframes.map { ($0.index as Int?, $0.value) }

        return lists.flatMap { keyframe, vertices in
            vertices.indices.compactMap { index in
                Self.point(of: vertices[index]).map { form in
                    (form, place(ofPoint: index, keyframe: keyframe, in: clip))
                }
            }
        }
    }

    // MARK: - Private
    // A leaf of the vertex at `index`: the keyframes that write it, or the static value where it writes it. Nil where
    // neither does.
    private func leaf<Value>(
        of index: Int,
        read: (JSONValue) -> Value?
    ) -> PropertyValue<Value>? {
        let keyframed = keyframes.compactMap { keyframe -> PropertyKeyframe<Value>? in
            guard keyframe.value.indices.contains(index), let value = read(keyframe.value[index]) else { return nil }

            return PropertyKeyframe(index: keyframe.index, at: keyframe.at, value: value, ease: keyframe.ease)
        }
        if !keyframed.isEmpty {
            return .keyframes(keyframed)
        }
        guard let written, written.indices.contains(index) else { return nil }

        return read(written[index]).map { .value($0) }
    }

    private static func point(of vertex: JSONValue) -> PositionForm? {
        PathKeyTable.point(of: vertex).flatMap(PositionForm.init(value:))
    }

    // A vertex written as `[x, y]` writes no tangent.
    private static func tangent(
        _ vertex: JSONValue,
        key: String
    ) -> Point? {
        guard PathKeyTable.isVertexObject(vertex) else { return nil }

        let numbers = vertex.objectValue?[key]?.arrayValue?.compactMap(\.numberValue) ?? []
        return numbers.count == 2 ? Point(x: numbers[0], y: numbers[1]) : nil
    }
}
