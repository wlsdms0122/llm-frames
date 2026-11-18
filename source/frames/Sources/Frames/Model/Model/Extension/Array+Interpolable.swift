//
//  Array+Interpolable.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A list interpolates element by element, as a path's points do. Resolve stops on keyframes whose lists differ in
// length, so the two lists have the same count.
extension Array: Interpolable where Element: Interpolable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func interpolate(
        from start: [Element],
        to end: [Element],
        progress: Double
    ) -> [Element] {
        zip(start, end).map { start, end in .interpolate(from: start, to: end, progress: progress) }
    }

    // MARK: - Private
}
