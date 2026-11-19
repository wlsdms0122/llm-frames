//
//  LookError.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Stops of the look merge and of timing, at the place of the value they name. A caller that knows which clip and which
// theme layer a value came from gives them with it.
enum LookError: Error, Equatable, CustomStringConvertible, Sendable {
    case nothingBelow(place: Place)
    case partialOverList(place: Place)
    case missingLeaf(place: Place, key: String)
    case allZero(place: Place)
    case keyframedStatic(place: Place)
    case keyframedOff(place: Place)
    case formsDiffer(place: Place, forms: [String])
    case lengthsDiffer(place: Place, counts: [Int])
    case nullStructure(place: Place)
    case nullWithoutValue(place: Place)
    case staticAndKeyframed(place: Place)
    case outsideDomain(place: Place, value: Double)

    // MARK: - Property
    var description: String {
        switch self {
        case let .nothingBelow(place):
            "\(place): a partial value with no value below it to change"

        case let .partialOverList(place):
            "\(place): a partial choice over a list, where which entry it changes is ambiguous"

        case let .missingLeaf(place, key):
            "\(place): missing key \"\(key)\", which no layer gives"

        case let .allZero(place):
            "\(place): lengths that are all 0, which draw no dash"

        case let .keyframedStatic(place):
            "\(place) (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"

        case let .keyframedOff(place):
            "\(place) (keyframe): false or \"none\" turns a value off and is written on the clip, not in a keyframe"

        case let .formsDiffer(place, forms):
            "\(place) (keyframe): the clip and its keyframes write different forms: \(forms.joined(separator: ", "))"

        case let .lengthsDiffer(place, counts):
            "\(place) (keyframe): lists of different lengths: \(counts.map(String.init).joined(separator: ", "))"

        case let .nullStructure(place):
            "\(place) (keyframe): null stands for a leaf, not for an object or a list"

        case let .nullWithoutValue(place):
            "\(place) (keyframe): null points at the merged value, which holds none here"

        case let .staticAndKeyframed(place):
            "\(place): written as a static value and in every keyframe that writes it, so the static value never shows"

        case let .outsideDomain(place, value):
            "\(place): \(value) is outside the values this leaf takes"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // The same stop with its place moved, as a caller that knows where the value is written gives it.
    func placed(_ moved: (Place) -> Place) -> LookError {
        switch self {
        case let .nothingBelow(place):
            .nothingBelow(place: moved(place))

        case let .partialOverList(place):
            .partialOverList(place: moved(place))

        case let .missingLeaf(place, key):
            .missingLeaf(place: moved(place), key: key)

        case let .allZero(place):
            .allZero(place: moved(place))

        case let .keyframedStatic(place):
            .keyframedStatic(place: moved(place))

        case let .keyframedOff(place):
            .keyframedOff(place: moved(place))

        case let .formsDiffer(place, forms):
            .formsDiffer(place: moved(place), forms: forms)

        case let .lengthsDiffer(place, counts):
            .lengthsDiffer(place: moved(place), counts: counts)

        case let .nullStructure(place):
            .nullStructure(place: moved(place))

        case let .nullWithoutValue(place):
            .nullWithoutValue(place: moved(place))

        case let .staticAndKeyframed(place):
            .staticAndKeyframed(place: moved(place))

        case let .outsideDomain(place, value):
            .outsideDomain(place: moved(place), value: value)
        }
    }

    // MARK: - Private
}
