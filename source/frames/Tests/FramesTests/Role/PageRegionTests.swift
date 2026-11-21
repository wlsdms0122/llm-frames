//
//  PageRegionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

// The whole page of a page's grid at a scale, and the scale the decoder holds it at (FRAMES-21 Rules).
@Suite("PageRegion Tests")
struct PageRegionTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the whole page is read at the scale asked for, or at the held scale, its longer side the largest the decoder holds")
    func readsWholePageAtHeldScale() {
        // Given
        let size = Size(width: 300, height: 200)

        // When
        let asked = PageRegion.wholePage(of: size, atMost: 4, largest: 1_500)
        let held = PageRegion.wholePage(of: size, atMost: 4, largest: 600)

        // Then
        #expect(asked.scale == 4)
        #expect(asked.region == PageRegion(x: 0, y: 0, width: 1_200, height: 800))
        #expect(held.scale == PageRegion.heldScale(of: size, atMost: 4, largest: 600))
        #expect(held.scale == 2)
        #expect(held.region == PageRegion(x: 0, y: 0, width: 600, height: 400))
    }
}
