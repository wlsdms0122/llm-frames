//
//  AnimationChoice.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation choice as a document, a theme or a template writes it, merged over the default it changes: for each
// span, the preset whose span of that name plays, nil where none plays. `loop` is the preset the choice takes its
// spans from, its `preset`, and `entrance` and `exit` are that preset or the preset of the side written in its place.
// `by`, `stagger` and `order` are as written, nil where absent, and resolve checks them.
struct AnimationChoice: Equatable, Sendable {
    // MARK: - Property
    static let none = AnimationChoice(entrance: nil, loop: nil, exit: nil, by: nil, stagger: nil, order: nil)

    let entrance: PresetInstance?
    let loop: PresetInstance?
    let exit: PresetInstance?
    let by: TextUnit?
    let stagger: Double?
    let order: UnitOrder?

    // Every preset the choice names, each once for each span it gives.
    var instances: [PresetInstance] {
        [entrance, loop, exit].compactMap(\.self)
    }

    // MARK: - Initializer
    init(
        entrance: PresetInstance?,
        loop: PresetInstance?,
        exit: PresetInstance?,
        by: TextUnit?,
        stagger: Double?,
        order: UnitOrder?
    ) {
        self.entrance = entrance
        self.loop = loop
        self.exit = exit
        self.by = by
        self.stagger = stagger
        self.order = order
    }

    // `place` is where the choice is written. An object without `preset` takes its spans from no preset, as it stands
    // over `"none"` or where no default is taken, and plays the sides it writes.
    init?(
        value: JSONValue,
        place: Place
    ) {
        switch value {
        case .string("none"):
            self = .none

        case .string:
            let instance = PresetInstance(value: value, place: place)
            self.init(entrance: instance, loop: instance, exit: instance, by: nil, stagger: nil, order: nil)

        case let .object(object):
            let base = PresetInstance(value: value, place: place)
            self.init(
                entrance: Self.side(object["entrance"], place: place.appending(key: "entrance"), base: base),
                loop: base,
                exit: Self.side(object["exit"], place: place.appending(key: "exit"), base: base),
                by: object["by"]?.stringValue.flatMap(TextUnit.init(rawValue:)),
                stagger: object["stagger"]?.numberValue,
                order: object["order"]?.stringValue.flatMap(UnitOrder.init(rawValue:))
            )

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A side not written is the base's, and one written `"none"` plays none.
    private static func side(
        _ value: JSONValue?,
        place: Place,
        base: PresetInstance?
    ) -> PresetInstance? {
        guard let value else { return base }
        guard value != .string("none") else { return nil }

        return PresetInstance(value: value, place: place)
    }
}
