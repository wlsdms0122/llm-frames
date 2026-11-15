//
//  Fixture.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

enum Fixture {
    static func json(_ text: String) throws -> JSONValue {
        try JSONReader().read(text)
    }

    static func object(_ text: String) throws -> JSONObject {
        try json(text).objectValue ?? JSONObject()
    }

    static let mediaKinds = MediaKindTable([
        "/abs/run.mp4": .video,
        "/abs/card.png": .image,
        "/abs/log.png": .image,
        "/abs/light-leak.mov": .video,
        "/abs/bgm.m4a": .audio,
        "/abs/ding.wav": .audio,
        "/abs/shot.png": .image,
        "/abs/before.png": .image,
        "/abs/after.png": .image,
        "pack/intro": .sequence,
        "pack/card": .image
    ])
}
