//
//  LeafValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A timed leaf's value once resolved: a number, a colour, or numbers moved as one (a point, an offset, a padding).
// Numbers interpolate linearly and per component, and a colour per channel, straight.
enum LeafValue: Interpolable {
    case number(Double)
    case color(Color)
    case numbers([Double])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func interpolate(
        from start: LeafValue,
        to end: LeafValue,
        progress: Double
    ) -> LeafValue {
        switch (start, end) {
        case let (.number(start), .number(end)):
            .number(.interpolate(from: start, to: end, progress: progress))

        case let (.numbers(start), .numbers(end)):
            .numbers(.interpolate(from: start, to: end, progress: progress))

        case let (.color(start), .color(end)):
            .color(Color(channels: .interpolate(from: start.channels, to: end.channels, progress: progress)))

        default:
            progress < 1 ? start : end
        }
    }

    // The value a sampled leaf takes where it is used, clamped to its domain; a colour is clamped per channel.
    func clamped(to domain: LeafDomain) -> LeafValue {
        switch self {
        case let .number(number):
            .number(domain.clamped(number))

        case let .numbers(numbers):
            .numbers(numbers.map(domain.clamped))

        case .color:
            self
        }
    }

    // MARK: - Private
}
