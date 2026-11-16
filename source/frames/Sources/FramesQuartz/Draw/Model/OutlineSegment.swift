//
//  OutlineSegment.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation

// A piece of a rounded outline: a straight edge, or a quarter arc about its centre starting at its angle, the angle
// growing clockwise in y-down coordinates.
enum OutlineSegment {
    case line(from: CGPoint, to: CGPoint)
    case arc(center: CGPoint, start: CGFloat, radius: CGFloat)

    // MARK: - Property
    var length: CGFloat {
        switch self {
        case let .line(from, to):
            hypot(to.x - from.x, to.y - from.y)

        case let .arc(_, _, radius):
            radius * .pi / 2
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
