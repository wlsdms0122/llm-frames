//
//  Interpolable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

protocol Interpolable: Equatable, Sendable {
    static func interpolate(
        from start: Self,
        to end: Self,
        progress: Double
    ) -> Self
}
