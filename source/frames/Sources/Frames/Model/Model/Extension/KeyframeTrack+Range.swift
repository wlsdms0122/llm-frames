//
//  KeyframeTrack+Range.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

extension KeyframeTrack where Value == Double {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The smallest and the largest value the track takes over `range`: held before its first keyframe and after its
    // last, and each span read over the part of it inside `range` with its ease's overshoot. Two keyframes at one
    // instant cut, so their span takes no time.
    func range(over range: TimeRange) -> ClosedRange<Double> {
        let held = [range.start, range.end].compactMap(value(at:))
        let spans = zip(keyframes, keyframes.dropFirst()).flatMap { start, end -> [Double] in
            let from = max(range.start, start.at)
            let to = min(range.end, end.at)
            guard end.at > start.at, from <= to else { return [] }

            let length = end.at - start.at
            let eased = start.ease.range(from: (from - start.at) / length, to: (to - start.at) / length)
            return [eased.lowerBound, eased.upperBound].map { progress in
                Double.interpolate(from: start.value, to: end.value, progress: progress)
            }
        }
        let values = held + spans

        return (values.min() ?? 0)...(values.max() ?? 0)
    }

    // MARK: - Private
}
