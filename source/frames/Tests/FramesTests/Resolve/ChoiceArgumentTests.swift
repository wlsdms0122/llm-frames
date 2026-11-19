//
//  ChoiceArgumentTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("Choice Argument Tests")
struct ChoiceArgumentTests {
    // MARK: - Property
    private let directory: PackDirectory

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("studio")
        try directory.write(
            ##"""
            { "description": "Dips to a colour, then the next clip comes up out of it.",
              "params": {
                "color":  { "type": "color", "default": "#000000", "description": "colour of the dip" },
                "length": { "type": "number", "default": 0.7, "description": "seconds the dip lasts" } },
              "seconds": { "param": "length" },
              "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] },
              "cover": { "color": { "param": "color" }, "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
            """##,
            in: "studio",
            at: "presets/transition/dip.json"
        )
        try directory.write(
            #"""
            { "description": "Springs up into place.",
              "params": { "bounce": { "type": "number", "default": 0.2, "description": "how far it overshoots" } },
              "entrance": { "seconds": 0.5, "ease": { "spring": { "bounce": { "param": "bounce" } } },
                            "keys": [ { "t": 0, "y": 0.2 }, { "t": 1, "y": 0 } ] } }
            """#,
            in: "studio",
            at: "presets/animation/spring-in.json"
        )
        try directory.write(
            #"""
            { "description": "Grains the picture like film.",
              "params": { "grain": { "type": "number", "default": 0.05, "description": "strength of the grain" } },
              "ops": [ { "op": "grain", "amount": { "param": "grain" }, "size": 2 } ] }
            """#,
            in: "studio",
            at: "presets/filter/film.json"
        )
        try directory.write(
            #"""
            { "description": "Blooms the highlights in a colour.",
              "params": { "tint": { "type": "color", "default": "#FFFFFF", "description": "colour of the bloom" } },
              "ops": [ { "op": "bloom", "amount": 0.4, "radius": 8, "color": { "param": "tint" } } ] }
            """#,
            in: "studio",
            at: "presets/filter/glow.json"
        )
    }

    // MARK: - Test
    @Test("resolve applies a choice's arguments, so the resolved document holds plain values that read back and report")
    func resolvesArguments() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": [ "studio/film", { "preset": "studio/film", "args": { "grain": 0.02 } } ] },
                             { "media": "/abs/run.mp4", "in": 0, "out": 3, "transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B" } } } ],
              "clips": [ { "title": "a", "style": "subtitle", "at": [0, 2], "animation": { "entrance": { "preset": "studio/spring-in", "args": { "bounce": 0.4 } }, "exit": "none" } } ] }
            """##)
        let sequence = try ResolvedSequence(plan: planner().plan(document), hashes: FileHashTable())

        // When
        let text = ResolvedDocumentWriter().write(sequence)
        let read = try ResolvedDocumentReader().read(text)
        let report = TimelineReporter(planner: planner()).report(of: read)

        // Then
        let json = try Fixture.object(text)
        let storyline = json["storyline"]?.arrayValue ?? []
        let filter = storyline.first?.objectValue?["filter"]?.arrayValue?.compactMap { $0.objectValue?["amount"] }
        let transition = storyline.last?.objectValue?["transition"]?.objectValue
        let entrance = json["clips"]?.arrayValue?.first?.objectValue?["animation"]?.objectValue?["entrance"]?.objectValue
        #expect(filter == [.number(0.05), .number(0.02)])
        #expect(transition?["cover"]?.objectValue?["color"] == .string("#1B3A6BFF"))
        #expect(transition.map { ($0["end"]?.numberValue ?? 0) - ($0["start"]?.numberValue ?? 0) } == 1)
        #expect(entrance?["ease"] == (try Fixture.json(#"{ "spring": { "bounce": 0.4 } }"#)))
        #expect(!text.contains("params") && !text.contains("param\""))
        #expect(read == sequence)
        #expect(!report.text.isEmpty)
    }

    @Test("a template passes its own arguments on to a preset only in a choice's args, and the preset's other parameters keep their defaults")
    func passesTemplateArgumentsOnlyThroughArgs() throws {
        // Given
        let template = try Fixture.json(##"""
            { "kind": "sequence",
              "params": {
                "tint":   { "type": "color", "default": "#FF0000", "description": "colour the dip goes to" },
                "length": { "type": "number", "default": 3, "description": "seconds of each shot" } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": { "param": "length" } },
                             { "media": "/abs/run.mp4", "in": 0, "out": { "param": "length" },
                               "transition": { "preset": "studio/dip", "args": { "color": { "param": "tint" } } } } ] }
            """##)
        let arguments = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(##"{ "tint": "#00FF00", "length": 2 }"##))

        // When
        let plan = try planner().plan(template, arguments: arguments)

        // Then
        let transition = try #require(plan.time.storyline.last?.transition)
        #expect(transition.definition.cover?.source == .color("#00FF00FF"))
        #expect(transition.definition.seconds == 0.7)
    }

    @Test("a template's choice option may be a preset with arguments, and an argument that is not one of its options stops")
    func takesPresetWithArgumentsAsOption() throws {
        // Given
        let template = try Fixture.json(##"""
            { "kind": "sequence",
              "params": {
                "look": { "type": "choice", "default": "studio/dip", "description": "how the shots join",
                          "options": [ "studio/dip", { "preset": "studio/dip", "args": { "color": "#1B3A6B" } } ] } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 },
                             { "media": "/abs/run.mp4", "in": 0, "out": 3, "transition": { "param": "look" } } ] }
            """##)
        let blue = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(##"{ "look": { "preset": "studio/dip", "args": { "color": "#1B3A6B" } } }"##))
        let red = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(##"{ "look": { "preset": "studio/dip", "args": { "color": "#FF0000" } } }"##))

        // When
        let defaults = try planner().plan(template)
        let given = try planner().plan(template, arguments: blue)
        let error = #expect(throws: ModelError.self) { try planner().plan(template, arguments: red) }

        // Then
        #expect(defaults.time.storyline.last?.transition?.definition.cover?.source == .color("#000000FF"))
        #expect(given.time.storyline.last?.transition?.definition.cover?.source == .color("#1B3A6BFF"))
        #expect(error?.description.hasPrefix("/abs/args.json: look (template arguments): expected ") == true, "\(error?.description ?? "no error")")
    }

    @Test("a theme default passes arguments as a clip's choice does, and a bad one stops when the theme is read, naming the default")
    func readsThemeDefaultArguments() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": { "preset": "studio/dip", "args": { "color": "#1B3A6B" } } } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 }, { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] }
            """##)
        let broken = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": { "preset": "studio/dip", "args": { "length": 0 } } } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] }
            """##)

        // When
        let plan = try planner().plan(document)
        let error = #expect(throws: PresetError.self) { try planner().plan(broken) }

        // Then
        #expect(plan.time.storyline.last?.transition?.definition.cover?.source == .color("#1B3A6BFF"))
        #expect(error?.description.hasPrefix(#"theme.defaults.transition (transition choice): its arguments give "studio/dip" a value it does not take"#) == true, "\(error?.description ?? "no error")")
    }

    @Test("a theme colour a theme default names through its arguments may be the theme's own or the base theme's")
    func takesThemeDefaultColorArguments() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "colors": { "brand": "#1B3A6B" }, "defaults": {
                "transition": { "preset": "studio/dip", "args": { "color": "brand" } },
                "filter": { "preset": "studio/glow", "args": { "tint": "shadow" } } } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 }, { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] }
            """##)

        // When
        let plan = try planner().plan(document)

        // Then
        #expect(plan.time.storyline.last?.transition?.definition.cover?.source == .color("#1B3A6BFF"))
    }

    @Test(
        "a theme colour a theme default names through its arguments that the theme does not hold stops when the theme is read, though no clip takes the default",
        arguments: [
            (
                #"{ "transition": { "preset": "studio/dip", "args": { "color": "brand" } } }"#,
                #"theme.defaults.transition (defaults): the preset names the colour "brand", which is not in the theme's colors"#
            ),
            (
                #"{ "filter": [ "studio/film", { "preset": "studio/glow", "args": { "tint": "brand" } } ] }"#,
                #"theme.defaults.filter[1] (defaults): the preset names the colour "brand", which is not in the theme's colors"#
            )
        ]
    )
    func refusesUnknownThemeDefaultColorArgument(
        defaults: String,
        expected: String
    ) throws {
        // Given
        let document = try Fixture.json(
            ##"{ "kind": "sequence", "theme": { "defaults": \##(defaults) }, "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##
        )

        // When
        let error = #expect(throws: ResolveError.self) { try planner().plan(document) }

        // Then
        #expect(error?.description == expected)
    }

    // MARK: - Private
    private func planner() -> DocumentPlanner {
        DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: PresetLibrary(packs: directory.packs),
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: directory.library()
        )
    }
}
