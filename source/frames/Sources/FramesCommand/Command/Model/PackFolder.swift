//
//  PackFolder.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// A folder a pack holds files in apart from its presets, by the kind `packs <pack>` lists them as. Where its kind of
// file takes `pathExtension`, the names leave it out. A font is found by its family, not by a name, so it is listed
// by its file.
struct PackFolder: Equatable, Sendable {
    // MARK: - Property
    static let template = PackFolder(kind: "template", folder: "templates", pathExtension: "json", isNamed: true)
    static let all = [
        PackFolder(kind: "theme", folder: "themes", pathExtension: "json", isNamed: true),
        template,
        PackFolder(kind: "lut", folder: "luts", pathExtension: "cube", isNamed: true),
        PackFolder(kind: "media", folder: "media", pathExtension: nil, isNamed: true),
        PackFolder(kind: "font", folder: "fonts", pathExtension: nil, isNamed: false)
    ]

    let kind: String
    let folder: String
    let pathExtension: String?
    let isNamed: Bool

    // MARK: - Initializer
    init(
        kind: String,
        folder: String,
        pathExtension: String?,
        isNamed: Bool
    ) {
        self.kind = kind
        self.folder = folder
        self.pathExtension = pathExtension
        self.isNamed = isNamed
    }

    // MARK: - Public
    // MARK: - Private
}
