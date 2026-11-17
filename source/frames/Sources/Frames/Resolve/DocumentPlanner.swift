//
//  DocumentPlanner.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Plans a whole document as a command takes it: checked with what the library finds, with `--theme` over the base
// theme, or, for a template, instantiated with `--args` on the base theme. Only its arguments change a template, so
// it takes no `--theme`, and a document that is not a template takes no `--args`.
package struct DocumentPlanner: Sendable {
    // MARK: - Property
    private let library: ReferenceLibrary
    private let planner: TimePlanner
    private let sequencePlanner: SequencePlanner
    private let checker: KeyChecker
    private let reader: TemplateReader
    private let instantiator: TemplateInstantiator
    private let merger = ThemeMerger()

    // MARK: - Initializer
    init(
        mediaFacts: any MediaFactProvider,
        presets: any PresetProvider,
        ocr: any OCRProvider,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.library = library
        self.planner = TimePlanner(mediaFacts: mediaFacts, presets: presets, library: library)
        self.sequencePlanner = SequencePlanner(
            ocr: ocr,
            tracker: tracker,
            shaper: shaper,
            presets: presets,
            library: library
        )
        self.checker = KeyChecker(mediaKinds: library)
        self.reader = TemplateReader(mediaKinds: library)
        self.instantiator = TemplateInstantiator(mediaKinds: library)
    }

    // The planner a command plans with: presets from `presets`, and what a document names found in `packs`, with the
    // facts of its media from `mediaFacts`.
    package init(
        mediaFacts: any MediaFactProvider,
        presets: PresetLibrary,
        ocr: any OCRProvider,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        packs: PackLibrary
    ) {
        self.init(
            mediaFacts: mediaFacts,
            presets: presets,
            ocr: ocr,
            tracker: tracker,
            shaper: shaper,
            library: ReferenceLibrary(packs: packs, mediaFacts: mediaFacts)
        )
    }

    // MARK: - Public
    // `theme` is the `--theme` name as written.
    func plan(
        _ document: JSONValue,
        theme: String? = nil,
        arguments: ArgumentFile? = nil
    ) throws -> SequencePlan {
        let template = try reader.template(from: document, place: .root)
        let documentKind = document.objectValue?["kind"]?.stringValue ?? ""

        guard template.declaresParameters else {
            guard arguments == nil else {
                throw PackError.argumentsWithoutTemplate(place: .root, kind: documentKind)
            }

            let merged = try self.theme(named: theme)

            return try sequencePlanner.plan(try planner.plan(document: document, theme: merged))
        }
        guard theme == nil else { throw PackError.themeOnTemplate(place: .root, kind: documentKind) }

        let argumentPlace = arguments?.place ?? .root
        if let arguments {
            try checker.check(
                arguments.value,
                as: TemplateKeyTable.arguments,
                place: argumentPlace,
                kind: TemplateKeyTable.argumentsKind
            )
        }

        let instance = try instantiator.instance(
            of: template,
            arguments: arguments?.value.objectValue ?? JSONObject(),
            place: argumentPlace
        )
        // The command line is the caller, and it gives a template no theme, so what it was given starts from the base.
        let argumentThemes = ArgumentThemeTable(instance: instance, place: .root, theme: .base, passedOnThemes: .empty)
        let sequence = SequenceReader(argumentThemes: argumentThemes).sequence(from: instance.document)

        return try sequencePlanner.plan(try planner.plan(sequence, theme: .base))
    }

    // The resolved document of what `plan` decides, with every file it names pinned.
    package func resolved(
        _ document: JSONValue,
        theme: String? = nil,
        arguments: ArgumentFile? = nil
    ) throws -> ResolvedSequence {
        try ResolvedSequence(plan: plan(document, theme: theme, arguments: arguments), hashes: FileHasher())
    }

    // MARK: - Private
    private func theme(named name: String?) throws -> MergedTheme {
        guard let name else { return .base }
        guard let layer = try library.theme(named: name) else { throw PackError.unknownThemeOption(name: name) }

        return try merger.merge([layer], over: .base)
    }
}
