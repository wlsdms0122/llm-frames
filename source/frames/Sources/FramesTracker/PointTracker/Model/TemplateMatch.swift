//
//  TemplateMatch.swift
//  FramesTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Where a template best matches a window, as the offset of its centre from the window's in the window's pixels, and
// the correlation there, from -1 to 1.
struct TemplateMatch: Sendable {
    // MARK: - Property
    let offset: CGPoint
    let correlation: Double

    // MARK: - Initializer
    init(
        offset: CGPoint,
        correlation: Double
    ) {
        self.offset = offset
        self.correlation = correlation
    }

    // MARK: - Public
    // MARK: - Private
}
