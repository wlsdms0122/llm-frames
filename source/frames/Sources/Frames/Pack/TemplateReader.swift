//
//  TemplateReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Reads a template from the document it is written in, checked against its parameter types with the media kinds it
// is given.
struct TemplateReader: Sendable {
    // MARK: - Property
    private let checker: KeyChecker

    // MARK: - Initializer
    init(mediaKinds: any MediaKindProvider) {
        self.checker = KeyChecker(mediaKinds: mediaKinds)
    }

    // MARK: - Public
    // `place` is where the template is written.
    func template(
        from document: JSONValue,
        place: Place
    ) throws -> Template {
        let references = try checker.check(template: document, place: place)

        return Template(
            document: document,
            place: place,
            parameters: Parameter.declared(in: document),
            references: references
        )
    }

    // MARK: - Private
}
