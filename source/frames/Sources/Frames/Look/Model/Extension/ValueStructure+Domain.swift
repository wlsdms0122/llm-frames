//
//  ValueStructure+Domain.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

extension ValueStructure {
    // MARK: - Public
    // Each number of a written value against the domain of its leaf, and each key with a check against it, where the
    // value is written. A place in `sampled` holds one keyframe's value of a leaf two keyframes or more write, which
    // may take any value its samples take.
    func checkDomains(
        of value: JSONValue,
        place: Place,
        sampled: Set<Place> = []
    ) throws {
        switch (value, self) {
        case let (.object(object), .object(structure)):
            for (key, child) in structure.keys {
                guard let member = object[key] else { continue }

                let memberPlace = place.appending(key: key)
                if let check = structure.checks[key], let failure = check.failure(of: member) {
                    throw LookError.failedCheck(place: memberPlace, check: check, failure: failure)
                }
                try child.checkDomains(of: member, place: memberPlace, sampled: sampled)
            }

        case let (.object(object), .map(element)):
            for member in object.members {
                try element.checkDomains(of: member.value, place: place.appending(key: member.key), sampled: sampled)
            }

        case let (.object(object), .choice):
            guard let form = form(of: object), let structure = structure(ofForm: form.name) else { return }

            try structure.checkDomains(of: .object(form.body), place: place, sampled: sampled)

        case let (.array(elements), .list), let (.array(elements), .tuple):
            for (index, value) in elements.enumerated() {
                try element(at: index).checkDomains(of: value, place: place.appending(index: index), sampled: sampled)
            }

        case let (_, .leaf(kind)):
            try (sampled.contains(place) ? kind.domain.sampled : kind.domain).check(value, place: place)

        default:
            return
        }
    }

    // MARK: - Private
}
