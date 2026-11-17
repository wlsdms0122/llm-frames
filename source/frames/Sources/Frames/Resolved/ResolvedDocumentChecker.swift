//
//  ResolvedDocumentChecker.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Decides whether a resolved document can be read, before anything reads the rest of it: a frames reads one written by
// a frames of its own major version at its minor version or an earlier one, and refuses any other, naming both
// versions. Its theme and arguments are already written in, so `--theme` or `--args` with it stops. Nothing checks a
// resolved document's keys, so its stops name its `kind` as written.
struct ResolvedDocumentChecker: Sendable {
    // MARK: - Property
    let current: String

    // MARK: - Initializer
    init(current: String = FramesVersion.current) {
        self.current = current
    }

    // MARK: - Public
    // The version the document was written by, or nil when it is a document, not a resolved one. `theme` is the
    // `--theme` name and `arguments` the `--args` file, as given.
    func version(
        of document: JSONValue,
        theme: String?,
        arguments: ArgumentFile?
    ) throws -> String? {
        let object = document.objectValue ?? JSONObject()
        guard let resolved = object["resolved"] else { return nil }

        let kind = object["kind"]?.stringValue ?? "document"
        guard theme == nil else { throw ResolveError.optionOnResolved(place: .root, kind: kind, option: "--theme") }
        guard arguments == nil else { throw ResolveError.optionOnResolved(place: .root, kind: kind, option: "--args") }

        let written = resolved.stringValue ?? resolved.written
        guard isReadable(written) else {
            throw ResolveError.unreadableResolvedVersion(
                place: Place.root.appending(key: "resolved"),
                kind: kind,
                written: written,
                current: current
            )
        }

        return written
    }

    // Whether this frames reads what a frames of the version wrote: a resolved document, or a display list or mix plan,
    // which are read by the same rule.
    func isReadable(_ written: String) -> Bool {
        guard let version = numbers(of: written), let frames = numbers(of: current) else { return false }

        return version[0] == frames[0] && version[1] <= frames[1]
    }

    // MARK: - Private
    // `major.minor.patch`, each only digits, so a sign, a space or a missing part does not pass for a version.
    private func numbers(of version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber } ? Int(part) : nil
        }
        guard parts.count == 3, numbers.count == 3 else { return nil }

        return numbers
    }
}
