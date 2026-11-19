//
//  ChoiceOptionCheckerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("ChoiceOptionChecker Tests")
struct ChoiceOptionCheckerTests {
    // MARK: - Property
    private let directory: PackDirectory

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("studio")
        try directory.write(
            ##"""
            { "description": "Dips to a colour.",
              "params": { "color": { "type": "color", "default": "#000000", "description": "colour of the dip" } },
              "seconds": 0.7,
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
            { "description": "Bounces up into place.",
              "params": { "bounce": { "type": "number", "default": 0.5, "description": "how far it overshoots" } },
              "entrance": { "seconds": 0.5, "ease": { "spring": { "bounce": { "param": "bounce" } } },
                            "keys": [ { "t": 0, "y": 0.4 }, { "t": 1, "y": 0 } ] } }
            """#,
            in: "studio",
            at: "presets/animation/bounce-in.json"
        )
        try directory.write(
            #"""
            { "description": "Fades in.", "entrance": { "seconds": 0.5, "keys": [ { "t": 0, "opacity": 0 }, { "t": 1, "opacity": 1 } ] } }
            """#,
            in: "studio",
            at: "presets/animation/fade-in.json"
        )
        try directory.write(
            ##"{ "colors": { "accent": "#1B3A6B" }, "styles": { "name": { "size": 56 } }, "shapes": { "card": { "radius": 12 } } }"##,
            in: "studio",
            at: "themes/look.json"
        )
        try directory.write(
            ##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "params": {
                "join": { "type": "choice", "default": "studio/dip", "options": [ "studio/dip", "studio/nope" ], "description": "how the shots join" } },
              "storyline": [ { "solid": "#000000", "duration": 1 }, { "solid": "#FFFFFF", "duration": 1, "transition": { "param": "join" } } ] }
            """##,
            in: "studio",
            at: "templates/join.json"
        )
    }

    // MARK: - Test
    @Test("an option of a transition choice that names no preset stops, though the default and the argument name one")
    func stopsOnMissingTransitionOption() throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "params": {
                "join": { "type": "choice", "default": "studio/dip", "options": [ "studio/dip", "studio/nope" ], "description": "how the shots join" } },
              "storyline": [ { "solid": "#000000", "duration": 1 }, { "solid": "#FFFFFF", "duration": 1, "transition": { "param": "join" } } ] }
            """##)
        let arguments = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(#"{ "join": "studio/dip" }"#))

        // When
        let error = #expect(throws: PackError.self) { try sut.plan(document, arguments: arguments) }

        // Then
        #expect(error == .unknownOption(
            place: Place(components: [.key("storyline"), .index(1, id: nil), .key("transition")]),
            kind: "solid",
            name: "join",
            option: .string("studio/nope"),
            target: "transition preset"
        ))
        #expect(error?.description.contains(#"parameter "join" offers "studio/nope""#) == true)
    }

    @Test("a template used as media is checked with every option before its arguments are")
    func stopsOnMissingOptionOfTemplateMedia() throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "storyline": [ { "media": { "template": "studio/join", "args": { "join": "studio/dip", "unknown": 1 } } } ] }
            """##)

        // When
        let error = #expect(throws: PackError.self) { try sut.plan(document) }

        // Then
        #expect(error == .unknownOption(
            place: Place(file: "studio/join", components: [.key("storyline"), .index(1, id: nil), .key("transition")]),
            kind: "solid",
            name: "join",
            option: .string("studio/nope"),
            target: "transition preset"
        ))
    }

    @Test("an option of the preset member of a choice is checked with the arguments written beside it")
    func checksArgumentsBesideOption() throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "params": {
                "move": { "type": "choice", "default": "studio/spring-in", "options": [ "studio/spring-in", "studio/fade-in" ], "description": "how the title comes in" } },
              "storyline": [ { "solid": "#000000", "duration": 2 } ],
              "clips": [ { "title": "a", "style": "subtitle", "at": [0, 2],
                           "animation": { "entrance": { "preset": { "param": "move" }, "args": { "bounce": 0.4 } }, "exit": "none" } } ] }
            """##)

        // When
        let error = #expect(throws: ParameterError.self) { try sut.plan(document) }

        // Then
        #expect(error == .unknownArgument(
            place: Place(components: [.key("clips"), .index(0, id: nil), .key("animation"), .key("entrance"), .key("args")]),
            kind: ChoiceKeyTable.argumentsKind,
            name: "bounce",
            allowed: []
        ))
    }

    @Test(
        "an option that names a text style, a shape style or a colour the template's theme does not hold stops",
        arguments: [
            (
                #"{ "type": "choice", "default": "name", "options": [ "name", "nope" ], "description": "style" }"#,
                #"{ "title": "a", "style": { "param": "pick" }, "at": [0, 1] }"#,
                "title",
                "text style"
            ),
            (
                #"{ "type": "choice", "default": "card", "options": [ "card", "nope" ], "description": "style" }"#,
                #"{ "shape": "rect", "style": { "param": "pick" }, "area": [0, 0, 10, 10], "at": [0, 1] }"#,
                "rect",
                "shape style"
            ),
            (
                ##"{ "type": "choice", "default": "accent", "options": [ "accent", "#FF0000", "nope" ], "description": "fill" }"##,
                #"{ "shape": "rect", "fill": { "param": "pick" }, "area": [0, 0, 10, 10], "at": [0, 1] }"#,
                "rect",
                "theme colour"
            )
        ]
    )
    func stopsOnMissingThemeName(
        parameter: String,
        clip: String,
        kind: String,
        target: String
    ) throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": "studio/look", "format": { "size": [1920, 1080] },
              "params": { "pick": \##(parameter) },
              "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ \##(clip) ] }
            """##)

        // When
        let error = #expect(throws: PackError.self) { try sut.plan(document) }

        // Then
        let key = target == "theme colour" ? "fill" : "style"
        #expect(error == .unknownOption(
            place: Place(components: [.key("clips"), .index(0, id: nil), .key(key)]),
            kind: kind,
            name: "pick",
            option: .string("nope"),
            target: target
        ))
    }

    @Test("an option of a template's theme that names no theme stops")
    func stopsOnMissingTheme() throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "param": "look" }, "format": { "size": [1920, 1080] },
              "params": { "look": { "type": "choice", "default": "studio/look", "options": [ "studio/look", "studio/nope" ], "description": "the look" } },
              "storyline": [ { "solid": "#000000", "duration": 1 } ] }
            """##)

        // When
        let error = #expect(throws: PackError.self) { try sut.plan(document) }

        // Then
        #expect(error == .unknownOption(
            place: Place(components: [.key("theme")]),
            kind: "sequence",
            name: "look",
            option: .string("studio/nope"),
            target: "theme"
        ))
    }

    @Test("a template whose every option is there plans, an argument without a default left out of the presets it reaches")
    func plansWhenEveryOptionIsThere() throws {
        // Given
        let sut = planner()
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": "studio/look", "format": { "size": [1920, 1080] },
              "params": {
                "join":   { "type": "choice", "default": "studio/dip", "options": [ "studio/dip", "cut" ], "description": "how the shots join" },
                "move":   { "type": "choice", "default": "studio/spring-in", "options": [ "studio/spring-in", "studio/bounce-in" ], "description": "how the title comes in" },
                "bounce": { "type": "number", "description": "how far the title overshoots" },
                "style":  { "type": "choice", "default": "name", "options": [ "name", "subtitle" ], "description": "style" } },
              "storyline": [ { "solid": "#000000", "duration": 1 }, { "solid": "#FFFFFF", "duration": 1, "transition": { "param": "join" } } ],
              "clips": [ { "title": "a", "style": { "param": "style" }, "position": [960, 540], "at": [0, 1],
                           "animation": { "entrance": { "preset": { "param": "move" }, "args": { "bounce": { "param": "bounce" } } }, "exit": "none" } } ] }
            """##)
        let arguments = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(#"{ "move": "studio/bounce-in", "bounce": 0.4 }"#))

        // When
        let plan = try sut.plan(document, arguments: arguments)

        // Then
        #expect(plan.time.clips.first?.animation.entrance?.preset == "studio/bounce-in")
        #expect(plan.time.storyline.last?.transition?.preset == "studio/dip")
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
