//
//  MediaSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The forms a document names media in. A template instance and a parameter reference are filled before time is planned.
enum MediaSource: Equatable, Sendable {
    case file(String)
    case imageSequence(directory: String, fps: Double)
    case compound(SequenceDocument)
    case document(JSONObject)
    case template(String)
    case parameter(String)
}
