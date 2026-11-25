//
//  PresetTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames
import FramesTestMedia

// A fake preset library: the transitions, animations, filters, audio presets and heads it holds, by name, each filter,
// audio preset and head the JSON a pack publishes. Its heads are the ones the pack `frames` ships unless a test gives
// its own.
struct PresetTable: PresetProvider {
    // MARK: - Property
    let transitions: [String: TransitionPreset]
    let animations: [String: AnimationPreset]
    let filters: [String: String]
    let audio: [String: String]
    let heads: [String: String]

    // The heads the pack `frames` ships, by the names a document gives them.
    static let shippedHeads = Dictionary(
        uniqueKeysWithValues: ShippedHeads.names.map { name in ("frames/\(name)", ShippedHeads.text(name)) }
    )

    // MARK: - Initializer
    init(
        transitions: [String: TransitionPreset],
        animations: [String: AnimationPreset],
        filters: [String: String],
        audio: [String: String] = [:],
        heads: [String: String] = PresetTable.shippedHeads
    ) {
        self.transitions = transitions
        self.animations = animations
        self.filters = filters
        self.audio = audio
        self.heads = heads
    }

    // MARK: - Public
    // Its transitions and animations are plain and publish no parameters, so any argument stops as an unknown one.
    func transition(_ instance: PresetInstance) throws -> TransitionPreset? {
        try checkArguments(of: instance)
        return transitions[instance.name]
    }

    func animation(_ instance: PresetInstance) throws -> AnimationPreset? {
        try checkArguments(of: instance)
        return animations[instance.name]
    }

    func filter(_ instance: PresetInstance) throws -> FilterPreset? {
        try publishedFilter(named: instance.name).map { try PresetReader().filter($0, instance: instance) }
    }

    func publishedFilter(named name: String) throws -> PublishedPreset<FilterPreset>? {
        guard let text = filters[name] else { return nil }

        return try PresetReader().publishedFilter(from: JSONReader().read(text), place: Place(file: name, components: []))
    }

    func audio(_ instance: PresetInstance) throws -> AudioPreset? {
        try publishedAudio(named: instance.name).map { try PresetReader().audio($0, instance: instance) }
    }

    func publishedAudio(named name: String) throws -> PublishedPreset<AudioPreset>? {
        guard let text = audio[name] else { return nil }

        return try PresetReader().publishedAudio(from: JSONReader().read(text), place: Place(file: name, components: []))
    }

    func head(named name: String) throws -> StrokeHead? {
        guard let text = heads[name] else { return nil }

        let value = try JSONReader().read(text)
        return try PresetReader().publishedHead(from: value, place: Place(file: name, components: [])).defaults.head
    }

    // A pack is there where it is `frames` or the table holds a preset of any kind in it.
    func names(
        of kind: PresetKind,
        inPack pack: String
    ) throws -> [String]? {
        let all = [Array(transitions.keys), Array(animations.keys), Array(filters.keys), Array(audio.keys), Array(heads.keys)]
        guard pack == "frames" || all.joined().contains(where: { $0.hasPrefix("\(pack)/") }) else { return nil }

        let names: [String] = switch kind {
        case .transition: Array(transitions.keys)
        case .animation: Array(animations.keys)
        case .filter: Array(filters.keys)
        case .audio: Array(audio.keys)
        case .head: Array(heads.keys)
        }
        return names.filter { $0.hasPrefix("\(pack)/") }.sorted()
    }

    // MARK: - Private
    private func checkArguments(of instance: PresetInstance) throws {
        _ = try ParameterFiller(checker: KeyChecker()).values(
            of: instance.arguments,
            for: [],
            place: instance.place.appending(key: "args"),
            kind: ChoiceKeyTable.argumentsKind
        )
    }
}
