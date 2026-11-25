//
//  ReferenceKind.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A kind of thing a pack holds and a name finds (FRAMES-17 Packs), each in a folder of its pack.
package enum ReferenceKind: Equatable, Sendable {
    case preset(PresetKind)
    case tool
    case theme
    case template
    case lut
    case media

    // MARK: - Property
    // The kind as a message names one, as `head preset`.
    var word: String {
        switch self {
        case let .preset(kind):
            "\(kind.rawValue) preset"

        case .tool:
            "tool"

        case .theme:
            "theme"

        case .template:
            "template"

        case .lut:
            "LUT"

        case .media:
            "media"
        }
    }

    // The kind as a message names more than one, as `head presets`.
    var plural: String {
        switch self {
        case .media:
            word

        default:
            "\(word)s"
        }
    }

    // How a name of the kind is spelled.
    var rule: String {
        switch self {
        case .preset:
            "A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"

        case .tool:
            "A tool is named <pack>/<name>, and the ones frames ships are frames/<name>"

        case .theme:
            "A theme is named <pack>/<name> or by an absolute path"

        case .template:
            "A template is named <pack>/<name> or by an absolute path"

        case .lut:
            "A LUT is named <pack>/<name> or by an absolute path"

        case .media:
            "Media is named <pack>/<name.ext>, <pack>/<dir> or by an absolute path"
        }
    }

    // Whether a name of the kind may be an absolute path, which names a file outside every pack.
    var takesPath: Bool {
        self != .tool
    }

    // The folder of a pack that holds the kind.
    var folder: String {
        switch self {
        case let .preset(kind):
            "presets/\(kind.rawValue)"

        case .tool:
            "tools"

        case .theme:
            "themes"

        case .template:
            "templates"

        case .lut:
            "luts"

        case .media:
            "media"
        }
    }

    // The extension a file of the kind takes, which its name leaves out, nil where the name is the entry's whole name.
    var pathExtension: String? {
        switch self {
        case .preset, .theme, .template:
            "json"

        case .lut:
            "cube"

        case .tool, .media:
            nil
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
