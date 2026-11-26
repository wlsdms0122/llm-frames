//
//  NameHint.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a message adds to a name that finds nothing of its kind (FRAMES-17 Packs): what the name's pack holds of the
// kind, the packs there are where its pack is not one of them, or for a name of another spelling the nearest name of
// the kind the pack `frames` holds.
package enum NameHint: Equatable, Sendable {
    // The name is `<pack>/<name>` and its pack is there, holding `names`; `nearest` is the one near the name, where one
    // is.
    case pack(pack: String, names: [String], nearest: String?)
    // The name is `<pack>/<name>` and no pack has that name; `packs` are the packs there are, and `nearest` the one near
    // `pack`, where one is.
    case unknownPack(pack: String, packs: [String], nearest: String?)
    // The name is not `<pack>/<name>`, or is an absolute path where the kind takes none; `nearest` is the name the
    // pack `frames` holds that is near it, where one is.
    case spelling(nearest: String?)

    // MARK: - Property
    // The pack that ships with frames.
    static let shippedPack = "frames"

    // MARK: - Initializer
    // `packs` gives the names of the packs there are, and `names` the names a pack holds of the kind, as
    // `<pack>/<name>`, or nil where no pack has that name.
    package init(
        name: String,
        packs: () throws -> [String],
        names: (String) throws -> [String]?
    ) rethrows {
        switch PackReference(name) {
        case let .pack(pack, written):
            guard let held = try names(pack) else {
                let there = try packs()
                self = .unknownPack(pack: pack, packs: there, nearest: Self.nearest(to: pack, among: there))
                return
            }

            self = .pack(pack: pack, names: held, nearest: Self.nearest(to: written, among: held))

        case .path, nil:
            self = .spelling(nearest: Self.nearest(to: name, among: try names(Self.shippedPack) ?? []))
        }
    }

    // MARK: - Public
    // The sentences after the message's first, each led by ". ". `things` names what the kind is more than one of, as
    // `head presets`, and `rule` is how a name of the kind is spelled.
    func text(
        things: String,
        rule: String
    ) -> String {
        switch self {
        case let .pack(pack, names, nearest):
            let held = names.isEmpty
                ? "The pack \(quoted(pack)) holds no \(things)"
                : "The pack \(quoted(pack)) holds the \(things) \(names.joined(separator: ", "))"
            return ". " + (nearest.map { "Did you mean \(quoted($0))? " } ?? "") + held

        case let .unknownPack(pack, packs, nearest):
            let there = packs.isEmpty
                ? "There is no pack \(quoted(pack)), and there are no packs"
                : "There is no pack \(quoted(pack)), and the packs are \(packs.joined(separator: ", "))"
            return ". " + (nearest.map { "Did you mean the pack \(quoted($0))? " } ?? "") + there

        case let .spelling(nearest):
            return ". " + (nearest.map { "Did you mean \(quoted($0))? " } ?? "") + rule
        }
    }

    // The first of `names` whose last part, its `<name>` or the whole of a pack's name, is nearest `written`, where
    // one is near.
    static func nearest(
        to written: String,
        among names: [String]
    ) -> String? {
        nearest(to: written, among: names) { String($0.split(separator: "/").last ?? "") }
    }

    // The hint a stop on a name looked up in a set known where it stands ends with, `. Did you mean "<name>"?`, the
    // first in name order of `names` whose whole name is nearest `written`, or nothing where none is near.
    static func suggestion(
        for written: String,
        among names: [String]
    ) -> String {
        guard let near = nearest(to: written, among: names.sorted(), part: { $0 }) else { return "" }

        return ". Did you mean \(JSONValue.string(near).written)?"
    }

    // MARK: - Private
    // The first of `names` whose `part` is nearest `written`, where one is near: at an edit distance of at most 1, or
    // a third of the longer of the two where that is more.
    private static func nearest(
        to written: String,
        among names: [String],
        part: (String) -> String
    ) -> String? {
        let scored = names.map { name in
            let part = part(name)
            let allowed = max(1, max(written.count, part.count) / 3)
            return (name: name, distance: editDistance(Array(written), Array(part)), allowed: allowed)
        }
        let near = scored.filter { $0.distance <= $0.allowed }
        guard let least = near.map(\.distance).min() else { return nil }

        return near.first { $0.distance == least }?.name
    }

    // The fewest characters inserted, deleted or replaced to turn `source` into `target`.
    private static func editDistance(
        _ source: [Character],
        _ target: [Character]
    ) -> Int {
        var previous = Array(0...target.count)
        for (sourceIndex, sourceCharacter) in source.enumerated() {
            var current = [sourceIndex + 1]
            for (targetIndex, targetCharacter) in target.enumerated() {
                let replaced = previous[targetIndex] + (sourceCharacter == targetCharacter ? 0 : 1)
                current.append(min(replaced, previous[targetIndex + 1] + 1, current[targetIndex] + 1))
            }
            previous = current
        }

        return previous[target.count]
    }

    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
