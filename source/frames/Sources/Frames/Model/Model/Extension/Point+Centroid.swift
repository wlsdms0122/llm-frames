//
//  Point+Centroid.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The mean of points, the centre a track's fit takes each set of corners about (FRAMES-12).
extension Point {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    package static func centroid(of points: [Point]) -> Point {
        let count = Double(points.count)

        return Point(x: points.map(\.x).reduce(0, +) / count, y: points.map(\.y).reduce(0, +) / count)
    }

    // MARK: - Private
}
