//
//  PackError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PackError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingManifest(place: Place)
    case invalidEngine(place: Place, engine: String)
    case unsupportedEngine(place: Place, pack: String, engine: String, version: String)
    case duplicatePack(place: Place, name: String, shipped: String)
    case missingToolManifest(place: Place)
    case invalidRun(place: Place, run: String)
    case unexecutableRun(place: Place, run: String)
    case unreadableFile(file: String)
    case circularReference(place: Place, files: [String])
    case unknownThemeOption(reference: UnknownReference)
    case themeOnTemplate(place: Place, kind: String)
    case argumentsWithoutTemplate(place: Place, kind: String)
    case argumentOfWrongKind(place: Place, kind: String, name: String, type: String, found: MediaKind)
    case unknownOption(place: Place, kind: String, name: String, option: JSONValue, target: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .missingManifest(place):
            "\(place) (\(PackKeyTable.manifest.kind)): a pack holds a pack.json, and this one has none"

        case let .invalidEngine(place, engine):
            "\(place) (\(PackKeyTable.manifest.kind)): \(quoted(engine)) is not a range of versions. "
                + "Write ^major, ^major.minor or ^major.minor.patch"

        case let .unsupportedEngine(place, pack, engine, version):
            "\(place) (\(PackKeyTable.manifest.kind)): "
                + "pack \(quoted(pack)) is written for frames \(engine), and this is frames \(version)"

        case let .duplicatePack(place, name, shipped):
            "\(place) (\(PackKeyTable.manifest.kind)): "
                + "a pack named \(quoted(name)) ships with frames at \(shipped), so an installed one of that name stops. Rename or remove the installed one"

        case let .missingToolManifest(place):
            "\(place) (\(PackKeyTable.tool.kind)): a tool holds a tool.json, and this one has none"

        case let .invalidRun(place, run):
            "\(place) (\(PackKeyTable.tool.kind)): \(quoted(run)) is not the name of a file in the tool's directory"

        case let .unexecutableRun(place, run):
            "\(place) (\(PackKeyTable.tool.kind)): \(quoted(run)) is not an executable file in the tool's directory"

        case let .unreadableFile(file):
            "\(file): the file is there but cannot be read"

        case let .circularReference(place, files):
            "\(place) (document): "
                + "it holds itself through \(files.map(quoted).joined(separator: ", ")), so it never ends"

        case let .unknownThemeOption(reference):
            "--theme: \(reference)"

        case let .themeOnTemplate(place, kind):
            "\(place) (\(kind)): a template resolves on the base theme and its own theme, so it takes no --theme"

        case let .argumentsWithoutTemplate(place, kind):
            "\(place) (\(kind)): the document declares no params, so it takes no arguments"

        case let .argumentOfWrongKind(place, kind, name, type, found):
            "\(place) (\(kind)): parameter \(quoted(name)) takes \(type) media, found \(found.rawValue)"

        case let .unknownOption(place, kind, name, option, target):
            "\(place) (\(kind)): parameter \(quoted(name)) offers \(option.written), and there is no \(target) of that name"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
