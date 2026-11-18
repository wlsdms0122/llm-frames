//
//  TitleRun.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A run of a title as written: its text, and the theme text style it names, nil for the clip's style.
struct TitleRun: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let style: String?

    // MARK: - Initializer
    init(
        text: String,
        style: String?
    ) {
        self.text = text
        self.style = style
    }

    // MARK: - Public
    // A title as written: a string, which is one run in the clip's style, or its list of runs. The key checks let
    // only these through.
    static func runs(in title: JSONValue) -> [TitleRun] {
        if let text = title.stringValue {
            return [TitleRun(text: text, style: nil)]
        }

        return (title.arrayValue ?? []).map { run in
            TitleRun(text: run.objectValue?["text"]?.stringValue ?? "", style: run.objectValue?["style"]?.stringValue)
        }
    }

    // MARK: - Private
}
