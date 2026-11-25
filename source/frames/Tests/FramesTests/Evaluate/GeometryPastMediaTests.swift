//
//  GeometryPastMediaTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("Geometry Past Media Tests")
struct GeometryPastMediaTests {
    // MARK: - Property
    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a numeric crop past the media and the same region written {scale} draw the same picture")
    func drawsNumericCropAsScale() throws {
        // Given
        let numeric = try resolved(#"{ "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "crop": [-603, -1311, 2412, 5244] }"#)
        let scaled = try resolved(#"{ "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "crop": { "scale": 0.5 } }"#)

        // When
        let numericList = sut.displayList(of: numeric, at: 0.5)
        let scaledList = sut.displayList(of: scaled, at: 0.5)

        // Then
        #expect(numericList == scaledList)
        #expect(numeric.storyline[0].crop.values == [Crop(Rectangle(x: -603, y: -1311, width: 2412, height: 5244))])
    }

    @Test("a rect parented to a storyline clip keeps its width past the media's edge")
    func drawsRectPastMedia() throws {
        // Given
        let sequence = try resolved(#"""
            { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "connected": [
              { "parent": "screen", "kind": "rect", "area": [1000, 330, 400, 60], "stroke": { "width": 8 } } ] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        let item = try #require(list.items.last)
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the shape is a rect")
            return
        }
        #expect(rectangle.width == 400)
    }

    @Test("a storyline clip whose crop, conformed to the frame, lies wholly outside its media stops, as never visible")
    func refusesCropOutsideMedia() throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try resolved(#"{ "kind": "media", "media": "/abs/screen.mp4", "crop": [2000, 0, 603, 1311] }"#)
        }
        #expect(error?.description == "storyline[0].crop (video): never visible, since its crop conformed to its box is [2000, 0, 603, 1311], which lies wholly outside its media of 1206x2622")
    }

    // MARK: - Private
    private func resolved(_ storylineClip: String) throws -> ResolvedSequence {
        let document = #"{ "kind": "sequence", "storyline": [ \#(storylineClip) ] }"#
        return try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }
}
