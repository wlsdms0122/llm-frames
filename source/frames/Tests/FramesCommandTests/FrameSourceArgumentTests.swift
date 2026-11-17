//
//  FrameSourceArgumentTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import FramesCommand

@Suite("FrameSourceArgument Tests")
struct FrameSourceArgumentTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a .json file in any case, a pack template or - names a document, and any other absolute path a video",
        arguments: [
            ("/abs/intro.json", FrameSourceArgument.document("/abs/intro.json")),
            ("/abs/intro.JSON", .document("/abs/intro.JSON")),
            ("shorts/intro", .document("shorts/intro")),
            ("-", .document("-")),
            ("/abs/clip.mov", .video(path: "/abs/clip.mov")),
            ("/abs/clip", .video(path: "/abs/clip"))
        ]
    )
    func namesSource(
        argument: String,
        expected: FrameSourceArgument
    ) {
        // Given
        let text = argument

        // When
        let sut = FrameSourceArgument(text)

        // Then
        #expect(sut == expected)
    }
}
