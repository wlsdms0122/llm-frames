//
//  AreaValue+Found.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// The values of the area found, for an area that is not a clip area. A clip area gives an empty area found nowhere,
// so a test that expects a found area fails on it.
extension AreaValue {
    // MARK: - Property
    var rectangle: Rectangle { found?.rectangle ?? Rectangle(x: 0, y: 0, width: 0, height: 0) }
    var target: Rectangle { found?.target ?? Rectangle(x: 0, y: 0, width: 0, height: 0) }
    var mediaTime: Double { found?.mediaTime ?? -1 }
    var lines: [RecognisedLine] { found?.lines ?? [] }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
