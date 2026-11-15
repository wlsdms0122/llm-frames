//
//  MediaSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The forms a document names media in. `argument` is media a template instance was given, which keeps `theme`, the
// theme in effect where the instance is written, since that is the document that wrote it. A template's
// `argumentThemes` are the themes media in its arguments already keeps, when a template passes on what it was given.
enum MediaSource: Equatable, Sendable {
    case file(String)
    case imageSequence(directory: String, fps: Double)
    case compound(SequenceDocument)
    case document(JSONObject)
    case template(name: String, arguments: JSONObject, argumentThemes: PassedOnThemeTable)
    indirect case argument(MediaSource, theme: MergedTheme)
}
