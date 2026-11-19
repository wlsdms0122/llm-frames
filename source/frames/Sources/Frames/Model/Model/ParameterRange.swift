//
//  ParameterRange.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The range an op parameter is checked against, as `LookStructureTable.filterOperation` declares its leaf. A pair of
// numbers within 0 to 1 is a levels pair, whose black lies below its white.
enum ParameterRange: Sendable {
    case unit
    case positive
    case nonNegative
    case levels

    // MARK: - Property
    var description: String {
        switch self {
        case .unit:
            "within 0 to 1"

        case .positive:
            "above 0"

        case .nonNegative:
            "0 or more"

        case .levels:
            "within 0 to 1 with black below white"
        }
    }

    // The range of a sampled value, where a length or size may be 0.
    var sampled: ParameterRange {
        self == .positive ? .nonNegative : self
    }

    // MARK: - Initializer
    // Nil for a leaf whose every value is in range.
    init?(kind: LeafKind) {
        switch (kind.form, kind.domain) {
        case (.number, .positive):
            self = .positive

        case (.number, .nonNegative):
            self = .nonNegative

        case let (.number, .range(range)) where range == 0...1:
            self = .unit

        case let (.numbers(count: 2), .range(range)) where range == 0...1:
            self = .levels

        default:
            return nil
        }
    }

    // MARK: - Public
    func contains(_ value: JSONValue) -> Bool {
        switch (self, value) {
        case let (.unit, .number(number)):
            (0...1).contains(number)

        case let (.positive, .number(number)):
            number > 0

        case let (.nonNegative, .number(number)):
            number >= 0

        case let (.levels, .array(elements)):
            isLevels(elements.compactMap(\.numberValue))

        default:
            false
        }
    }

    // MARK: - Private
    private func isLevels(_ numbers: [Double]) -> Bool {
        guard numbers.count == 2 else { return false }

        let black = numbers[0]
        let white = numbers[1]
        return (0...1).contains(black) && (0...1).contains(white) && black < white
    }
}
