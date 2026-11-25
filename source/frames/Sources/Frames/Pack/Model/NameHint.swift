//
//  NameHint.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a message adds to a name that finds nothing in one of a pack's folders (FRAMES-17 Packs): what the name's pack
// holds there, or for a name of another spelling the nearest name the pack `frames` holds there.
package enum NameHint: Equatable, Sendable {
    // The name is `<pack>/<name>` and its pack is there, holding `names`; `nearest` is the one near the name, where one
    // is.
    case pack(pack: String, names: [String], nearest: String?)
    // The name is not `<pack>/<name>`, and the pack `frames` holds `nearest`, which is near it.
    case shipped(nearest: String)
    // The name is an absolute path, its pack is not there, or it is of another spelling and near nothing frames ships.
    case none

    // MARK: - Property
    // The pack that ships with frames.
    static let shippedPack = "frames"

    // MARK: - Initializer
    // `names` gives the names a pack holds in the folder, as `<pack>/<name>`, or nil where no pack has that name.
    package init(
        name: String,
        names: (String) throws -> [String]?
    ) rethrows {
        switch PackReference(name) {
        case .path:
            self = .none

        case let .pack(pack, written):
            guard let held = try names(pack) else {
                self = .none
                return
            }

            self = .pack(pack: pack, names: held, nearest: Self.nearest(to: written, among: held))

        case nil:
            let nearest = Self.nearest(to: name, among: try names(Self.shippedPack) ?? [])
            self = nearest.map { .shipped(nearest: $0) } ?? .none
        }
    }

    // MARK: - Public
    // The sentences after the message's first, each led by ". ". `things` names what the folder holds, as
    // `head presets`, and `rule` is how such a name is spelled.
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

        case let .shipped(nearest):
            return ". Did you mean \(quoted(nearest))? \(rule)"

        case .none:
            return ". \(rule)"
        }
    }

    // MARK: - Private
    // The first of `names` whose `<name>` is near `written`: at an edit distance of at most 1, or a third of the
    // longer of the two where that is more.
    private static func nearest(
        to written: String,
        among names: [String]
    ) -> String? {
        let scored = names.map { name in
            let part = String(name.split(separator: "/").last ?? "")
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
