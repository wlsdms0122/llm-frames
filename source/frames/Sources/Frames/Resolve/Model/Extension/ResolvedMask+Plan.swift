//
//  ResolvedMask+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A mask as resolve times it, from the timed value of one mask the key tables and timing have checked: its `shape`
// names its geometry, given by `area`, by the box `width`, `height` and `position`, or by `points`, and a path is
// a closed polyline.
extension ResolvedMask {
    // MARK: - Property
    // MARK: - Initializer
    init?(timed: TimedValue) {
        guard
            let shape = Self.fixed(timed["shape"])?.stringValue.flatMap(ShapeKind.init(rawValue:)),
            let mode = Self.fixed(timed["mode"])?.stringValue.flatMap(MaskMode.init(rawValue:)),
            let isInverted = Self.fixed(timed["invert"])?.boolValue,
            let feather = Self.numbers(timed["feather"])
        else {
            return nil
        }

        let geometry: ResolvedMaskGeometry
        if shape == .path {
            guard case let .list(elements) = timed["points"] else { return nil }

            geometry = .polyline(elements.compactMap { Self.points($0) })
        } else {
            guard let rectangle = Self.rectangle(of: timed) else { return nil }

            if shape == .rect, let radius = Self.numbers(timed["radius"]) {
                geometry = .rect(rectangle, radius: radius)
            } else {
                geometry = .ellipse(rectangle)
            }
        }

        self.init(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // MARK: - Public
    // MARK: - Private
    private static func rectangle(of timed: TimedValue) -> ResolvedMaskRectangle? {
        if let area = track(timed["area"]) {
            return .area(area.compactMap { keyframe in
                guard case let .numbers(numbers) = keyframe.value, numbers.count == 4 else { return nil }

                let rectangle = Rectangle(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
                return Keyframe(at: keyframe.at, value: rectangle, ease: keyframe.ease)
            })
        }
        guard
            let width = numbers(timed["width"]),
            let height = numbers(timed["height"]),
            let position = points(timed["position"])
        else {
            return nil
        }

        return .box(width: width, height: height, position: position)
    }

    private static func fixed(_ value: TimedValue?) -> JSONValue? {
        guard case let .fixed(json) = value else { return nil }

        return json
    }

    private static func track(_ value: TimedValue?) -> [Keyframe<LeafValue>]? {
        guard case let .track(keyframes) = value else { return nil }

        return keyframes
    }

    private static func numbers(_ value: TimedValue?) -> [Keyframe<Double>]? {
        track(value)?.compactMap { keyframe in
            guard case let .number(number) = keyframe.value else { return nil }

            return Keyframe(at: keyframe.at, value: number, ease: keyframe.ease)
        }
    }

    private static func points(_ value: TimedValue?) -> [Keyframe<Point>]? {
        track(value)?.compactMap { keyframe in
            guard case let .numbers(numbers) = keyframe.value, numbers.count == 2 else { return nil }

            return Keyframe(at: keyframe.at, value: Point(x: numbers[0], y: numbers[1]), ease: keyframe.ease)
        }
    }
}
