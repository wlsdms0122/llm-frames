//
//  DisplayList+Content.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// A list's items, an issue where it holds samples, and its sample lists, nil where it holds items.
extension DisplayList {
    // MARK: - Property
    var items: [DisplayItem] {
        guard case let .items(items) = content else {
            Issue.record("the list holds samples")
            return []
        }

        return items
    }

    var samples: [[DisplayItem]]? {
        guard case let .samples(samples) = content else { return nil }

        return samples
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
