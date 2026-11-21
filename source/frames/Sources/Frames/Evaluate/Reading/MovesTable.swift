//
//  MovesTable.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The Moves columns of FRAMES-20 as marks on the written members of each item kind, and the check that a sample list
// differs from the first only in the members they mark. A member a row does not name is equal in every sample, and a
// nested list in a picture's or a track matte's `source` is held to the same marks item by item.
struct MovesTable: Sendable {
    // MARK: - Property
    // A filter moves in its entries' `mix` and its ops' numeric parameters, the members a preset's `param` may stand
    // for. An op's name, a `lut` op's `file`, `sha256` and `space`, and a `grain` op's `seed` are equal in every sample.
    private static let filter = MovesMark.elements(.members(
        [
            "ops": .elements(.members(
                Dictionary(uniqueKeysWithValues: parameters.map { ($0, MovesMark.moves) }),
                other: .fixed
            )),
            "mix": .moves
        ],
        other: .fixed
    ))
    // Every numeric parameter a filter op is written with.
    private static let parameters = ["ev", "amount", "kelvin", "degrees", "input", "output", "radius", "color", "size"]
    // A source is a media frame or a page of a PDF, its media (a page's `page` included), `frame`, `colorSpace` and
    // `targetPeak` equal in every sample, or `{list}`, whose items take their marks and whose own `size`, `background`
    // and `compositing` are equal in every sample. A matte's `source` and `frame` are equal in every sample too.
    private static let source = MovesMark.members(["list": .members(["items": .items], other: .fixed)], other: .fixed)
    private static let common: [String: MovesMark] = [
        "transform": .moves,
        "opacity": .moves,
        "mask": .elements(.members(["geometry": .moves, "transform": .moves, "feather": .moves], other: .fixed)),
        "trackMatte": .members(["source": source], other: .fixed),
        "reveal": .moves
    ]
    // A glyph is written `[id, x, y]`: its id holds and its position moves.
    private static let kinds: [String: [String: MovesMark]] = [
        "picture": [
            "source": source,
            "rect": .moves,
            "dest": .moves,
            "filter": filter,
            "matte": .members(["progress": .moves], other: .fixed),
            "radius": .moves,
            "border": .members(["width": .moves, "color": .moves], other: .fixed),
            "shadow": .moves
        ],
        "path": [
            "geometry": .moves,
            "fill": .moves,
            "stroke": .members(
                ["width": .moves, "paint": .moves, "dash": .elements(.moves), "dashOffset": .moves],
                other: .fixed
            ),
            "trim": .moves,
            "shadow": .moves
        ],
        "glyphs": [
            "runs": .elements(.members(
                [
                    "color": .moves,
                    "stroke": .moves,
                    "highlight": .moves,
                    "underline": .moves,
                    "glyphs": .elements(.tuple([.fixed, .moves, .moves]))
                ],
                other: .fixed
            )),
            "unitBox": .moves,
            "unitGlyphBox": .moves,
            "background": .moves,
            "size": .moves
        ],
        "adjust": [
            "filter": filter
        ]
    ]

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The member of `sample` where it first differs from `first` in what the table does not mark, nil where it differs
    // in nothing else. Both are written lists of items.
    func difference(
        of sample: PlacedJSONValue,
        from first: PlacedJSONValue
    ) -> PlacedJSONValue? {
        difference(of: sample, from: first.value, by: .items)
    }

    // MARK: - Private
    private func difference(
        of sample: PlacedJSONValue,
        from first: JSONValue,
        by mark: MovesMark
    ) -> PlacedJSONValue? {
        switch (mark, sample.value, first) {
        case (.moves, _, _):
            return nil

        case (.fixed, .object, .object):
            return difference(of: sample, from: first, by: .members([:], other: .fixed))

        case (.fixed, .array, .array):
            return difference(of: sample, from: first, by: .elements(.fixed))

        case let (.members(marks, other), .object(object), .object(firstObject)):
            for key in firstObject.keys {
                guard let member = object[key], let firstMember = firstObject[key] else { return sample }

                let placed = PlacedJSONValue(member, place: sample.place.appending(key: key), kind: sample.kind)
                if let difference = difference(of: placed, from: firstMember, by: marks[key] ?? other) {
                    return difference
                }
            }

            return object.keys.count == firstObject.keys.count ? nil : sample

        case let (.elements(mark), .array(elements), .array(firstElements)):
            return difference(of: sample, elements: elements, from: firstElements) { _ in mark }

        case let (.tuple(marks), .array(elements), .array(firstElements)):
            return difference(of: sample, elements: elements, from: firstElements) { index in
                marks.indices.contains(index) ? marks[index] : .fixed
            }

        case let (.items, .array(elements), .array(firstElements)):
            guard elements.count == firstElements.count else { return sample }

            for (index, (element, firstElement)) in zip(elements, firstElements).enumerated() {
                let name = element.objectValue?["item"]?.stringValue ?? sample.kind
                let item = PlacedJSONValue(element, place: sample.place.appending(index: index), kind: name)
                let marks = Self.common.merging(Self.kinds[name] ?? [:]) { common, _ in common }
                if let difference = difference(of: item, from: firstElement, by: .members(marks, other: .fixed)) {
                    return difference
                }
            }

            return nil

        default:
            return sample.value == first ? nil : sample
        }
    }

    // `mark` gives the mark of the element at an index.
    private func difference(
        of sample: PlacedJSONValue,
        elements: [JSONValue],
        from firstElements: [JSONValue],
        by mark: (Int) -> MovesMark
    ) -> PlacedJSONValue? {
        guard elements.count == firstElements.count else { return sample }

        for (index, (element, firstElement)) in zip(elements, firstElements).enumerated() {
            let placed = PlacedJSONValue(element, place: sample.place.appending(index: index), kind: sample.kind)
            if let difference = difference(of: placed, from: firstElement, by: mark(index)) {
                return difference
            }
        }

        return nil
    }
}
