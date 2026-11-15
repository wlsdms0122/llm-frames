//
//  PackError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PackError: Error, Equatable, CustomStringConvertible, Sendable {
    case manifestSyntax(file: String, line: Int, column: Int, reason: String)
    case missingManifest(place: Place)
    case invalidEngine(place: Place, engine: String)
    case unsupportedEngine(place: Place, pack: String, engine: String, version: String)
    case misnamedPack(place: Place, name: String, directory: String)
    case duplicatePack(place: Place, name: String, shipped: String)
    case unreadableFile(file: String)
    case circularReference(place: Place, files: [String])
    case unknownThemeOption(name: String)
    case themeOnTemplate(place: Place, kind: String)
    case argumentsWithoutTemplate(place: Place, kind: String)
    case unknownArgument(place: Place, kind: String, name: String, allowed: [String])
    case missingArgument(place: Place, kind: String, name: String)
    case argumentOfWrongKind(place: Place, kind: String, name: String, type: String, found: MediaKind)

    // MARK: - Property
    var description: String {
        switch self {
        case let .manifestSyntax(file, line, column, reason):
            "\(file): line \(line), column \(column): \(reason)"

        case let .missingManifest(place):
            "\(place) (\(PackKeyTable.manifestKind)): a pack holds a manifest.toml, and this one has none"

        case let .invalidEngine(place, engine):
            "\(place) (\(PackKeyTable.manifestKind)): \(quoted(engine)) is not a range of versions. "
                + "Write ^major, ^major.minor or ^major.minor.patch"

        case let .unsupportedEngine(place, pack, engine, version):
            "\(place) (\(PackKeyTable.manifestKind)): "
                + "pack \(quoted(pack)) is written for frames \(engine), and this is frames \(version)"

        case let .misnamedPack(place, name, directory):
            "\(place) (\(PackKeyTable.manifestKind)): "
                + "the pack is named \(quoted(name)), but its directory is \(quoted(directory))"

        case let .duplicatePack(place, name, shipped):
            "\(place) (\(PackKeyTable.manifestKind)): "
                + "a pack named \(quoted(name)) ships with frames at \(shipped), so an installed one of that name stops"

        case let .unreadableFile(file):
            "\(file): the file is there but cannot be read"

        case let .circularReference(place, files):
            "\(place) (document): "
                + "it holds itself through \(files.map(quoted).joined(separator: ", ")), so it never ends"

        case let .unknownThemeOption(name):
            "--theme: unknown theme \(quoted(name)). A theme is named <pack>/<name> or by an absolute path"

        case let .themeOnTemplate(place, kind):
            "\(place) (\(kind)): a template resolves on the base theme and its own theme, so it takes no --theme"

        case let .argumentsWithoutTemplate(place, kind):
            "\(place) (\(kind)): the document declares no params, so it takes no arguments"

        case let .unknownArgument(place, kind, name, allowed):
            "\(place) (\(kind)): unknown argument \(quoted(name)). Allowed: \(allowed.joined(separator: ", "))"

        case let .missingArgument(place, kind, name):
            "\(place) (\(kind)): missing argument \(quoted(name)), which has no default"

        case let .argumentOfWrongKind(place, kind, name, type, found):
            "\(place) (\(kind)): parameter \(quoted(name)) takes \(type) media, found \(found.rawValue)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
