//
//  ValueStructure+Domain.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

extension ValueStructure {
    // MARK: - Public
    // Each number of a written value against the domain of its leaf, where the value is written. A place in `sampled`
    // holds one keyframe's value of a leaf two keyframes or more write, which may take any value its samples take.
    func checkDomains(
        of value: JSONValue,
        place: Place,
        sampled: Set<Place> = []
    ) throws {
        switch (value, self) {
        case let (.object(object), .object(structure)):
            for (key, child) in structure.keys {
                guard let member = object[key] else { continue }

                try child.checkDomains(of: member, place: place.appending(key: key), sampled: sampled)
            }

        case let (.object(object), .choice):
            guard let form = form(of: object), let structure = structure(ofForm: form.name) else { return }

            try structure.checkDomains(of: .object(form.body), place: place, sampled: sampled)

        case let (.array(elements), .list(element)):
            for (index, value) in elements.enumerated() {
                try element.checkDomains(of: value, place: place.appending(index: index), sampled: sampled)
            }

        case let (.number(number), .leaf(kind)):
            let fits = sampled.contains(place) ? kind.domain.contains : kind.domain.isSeen
            guard fits(number) else { throw LookError.outsideDomain(place: place, value: number) }

        default:
            return
        }
    }

    // MARK: - Private
}
